defmodule Workflows.CLI do
  alias Workflows.Parser
  alias Workflows.WorkflowExecutor
  alias Workflows.Registry

  def main(_args) do
    Application.ensure_all_started(:fp_lab4)

    IO.puts("""
    Workflow Orchestration System (интерактивный режим)
    =======================================================
    Введите команду. Для справки введите: help
    Для выхода: exit или quit
    """)

    interactive_loop()
  end

  def run_non_interactive(args) do
    Application.ensure_all_started(:fp_lab4)

    args
    |> parse_args()
    |> dispatch_command(false)
  end

  defp interactive_loop do
    prompt = "> "

    case IO.gets(prompt) do
      :eof ->
        IO.puts("\nПока!")
        :ok

      line ->
        line = String.trim(line)

        case line do
          "" ->
            interactive_loop()

          "exit" ->
            IO.puts("Выход из интерактивного режима")
            :ok

          "quit" ->
            IO.puts("Выход из интерактивного режима")
            :ok

          "clear" ->
            IO.write(IO.ANSI.clear())
            IO.write(IO.ANSI.home())
            interactive_loop()

          _ ->
            process_interactive_command(line)
            interactive_loop()
        end
    end
  end

  defp process_interactive_command(line) do
    args = parse_interactive_line(line)

    case args do
      [] ->
        :ok

      ["help" | _] ->
        print_help()

      ["list" | _] ->
        list_workflows()

      ["status", name] ->
        get_status(name)

      ["stop", name] ->
        stop_workflow(name)

      ["run", name, file_path] ->
        run_workflow(name, file_path)

      ["run", _name, _file_path | rest] when rest != [] and length(rest) > 0 ->
        IO.puts("Лишние аргументы: #{inspect(rest)}")
        IO.puts("Использование: run <name> <file_path>")

      ["debug"] ->
        show_debug_info()

      _ ->
        case parse_args(args) do
          {opts, _, []} ->
            dispatch_command({opts, [], []}, true)
          _ ->
            IO.puts("Неизвестная команда: #{line}")
            IO.puts("Введите 'help' для списка команд")
        end
    end
  end

  defp parse_interactive_line(line) do
    line
    |> String.split(~r/\s+(?=(?:[^"]*"[^"]*")*[^"]*$)/)
    |> Enum.map(fn
      <<"\"", rest::binary>> ->
        case String.split_at(rest, -1) do
          {middle, "\""} -> middle
          _ -> rest
        end
      arg -> arg
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_args(args) do
    OptionParser.parse(
      args,
      strict: [
        workflow: :string,
        file: :string,
        list: :boolean,
        status: :string,
        stop: :string,
        help: :boolean
      ],
      aliases: [
        w: :workflow,
        f: :file,
        l: :list,
        s: :status,
        h: :help
      ]
    )
  end

  defp dispatch_command({opts, _, _}, interactive) do
    cond do
      opts[:help] ->
        print_help()
        :ok

      opts[:list] ->
        list_workflows()
        :ok

      opts[:status] && opts[:status] != "" ->
        get_status(opts[:status])
        :ok

      opts[:stop] && opts[:stop] != "" ->
        stop_workflow(opts[:stop])
        :ok

      opts[:workflow] && opts[:file] ->
        run_workflow(opts[:workflow], opts[:file])
        :ok

      true ->
        if interactive do
          IO.puts("Неизвестная команда. Введите 'help' для справки")
        else
          print_help()
        end
        :error
    end
  end

  defp run_workflow(name, file_path) do
    IO.puts("Запуск workflow: #{name} из #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        case Parser.parse_workflow(content) do
          {:ok, workflow} ->
            case WorkflowExecutor.start_link({name, workflow}) do
              {:ok, pid} ->
                IO.puts("Workflow '#{name}' успешно запущен")
                IO.puts("PID: #{inspect(pid)}")

                Process.sleep(500)

                case Registry.lookup(name) do
                  [{pid, _}] ->
                    status = WorkflowExecutor.get_status(pid)
                    print_workflow_details(name, status)
                  [] ->
                    IO.puts("Workflow не найден в реестре")
                end

                :ok
              {:error, reason} ->
                IO.puts("Ошибка выполнения Workflow: #{inspect(reason)}")
                :error
            end
          {:error, reason} ->
            IO.puts("Ошибка парсинга Workflow: #{reason}")
            :error
        end
      {:error, reason} ->
        IO.puts("Ошибка чтения файла: #{reason}")
        :error
    end
  end

  defp list_workflows() do
    workflows = Registry.list()

    IO.puts("\nЗапущенные workflows:")

    if Enum.empty?(workflows) do
      IO.puts("   Нет запущенных workflows")
    else
      Enum.each(workflows, fn %{name: name, pid: pid} ->
        case WorkflowExecutor.get_status(pid) do
          %{status: status, started_at: started_at} ->
            runtime = DateTime.diff(DateTime.utc_now(), started_at)
            IO.puts("   #{name}: #{status} (запущен #{runtime} секунд назад)")
          _ ->
            IO.puts("   #{name}: статус неизвестен")
        end
      end)
    end
    :ok
  end

  defp get_status(name) do
    case Registry.lookup(name) do
      [{pid, _}] ->
        status = WorkflowExecutor.get_status(pid)
        print_workflow_details(name, status)
        :ok
      [] ->
        IO.puts("Workflow '#{name}' не найден")
        :error
    end
  end

  defp stop_workflow(name) do
    case Registry.lookup(name) do
      [{pid, _}] ->
        case GenServer.stop(pid, :normal) do
          :ok ->
            IO.puts("Workflow '#{name}' остановлен")
            :ok
          {:error, reason} ->
            IO.puts("Ошибка при остановке: #{inspect(reason)}")
            :error
        end
      [] ->
        IO.puts("Workflow '#{name}' не найден")
        :error
    end
  end

  defp print_workflow_details(name, status) do
    IO.puts("\nСтатус workflow: #{name}")

    IO.puts("Состояние: #{status.status}")
    IO.puts("Запущен: #{format_datetime(status.started_at)}")

    if status.completed_at do
      IO.puts("Завершен: #{format_datetime(status.completed_at)}")
      runtime = DateTime.diff(status.completed_at, status.started_at)
      IO.puts("Время выполнения: #{runtime} секунд")
    end

    if status.error do
      IO.puts("\nОшибка:")
      IO.puts("  #{inspect(status.error[:message])}")
    end

    if status.context do
      IO.puts("\nКонтекст (первые 5 ключей):")
      keys = Map.keys(status.context) |> Enum.take(5) |> Enum.map(&inspect/1) |> Enum.join(", ")
      IO.puts("   #{keys}")
    end
  end

  defp format_datetime(nil), do: "не определено"
  defp format_datetime(datetime) do
    DateTime.to_iso8601(datetime)
  end

  defp print_help() do
    IO.puts("""

    Orchestrator CLI

    Основные команды:
      help                 - Показать эту справку
      list                 - Показать список запущенных workflows
      status <name>        - Показать статус workflow
      stop <name>          - Остановить workflow
      run <name> <file>    - Запустить workflow
      clear                - Очистить экран
      exit/quit            - Выйти из интерактивного режима

    Примеры:
      run test workflows/test_workflow.yml
      list
      status test
      stop test

    Старый формат (с флагами):
      --workflow test --file workflows/test.yml
      --list
      --status test
      --stop test

    """)
  end

  defp show_debug_info() do
    IO.puts("Отладочная информация:")
    IO.puts("Приложение запущено: #{Application.started_applications() |> Enum.any?(fn {app, _, _} -> app == :fp_lab4 end)}")
    workflows = Registry.list()
    IO.puts("Зарегистрированных workflows: #{length(workflows)}")
    children = Supervisor.which_children(FpLab4.Supervisor)
    IO.puts("Дочерние процессы супервизора: #{length(children)}")
    memory = :erlang.memory()
    IO.puts("Используемая память: #{div(memory[:total], 1024 * 1024)} MB")
  end
end
