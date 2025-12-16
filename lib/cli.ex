defmodule Workflows.CLI do
  @moduledoc """
  Командный интерфейс для управления workflow системой.
  Поддерживает интерактивный и неинтерактивный режимы.
  """

  alias Workflows.Parser
  alias Workflows.WorkflowExecutor
  alias Workflows.Registry

  def main(_args) do
    Application.ensure_all_started(:fp_lab4)

    IO.puts("""
    Workflow Orchestration System (интерактивный режим)
    =======================================================
    Введите команду. Для справки введите: help
    Для выхода: exit
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
    handle_command(args, line)
  end

  defp handle_command([], _), do: :ok

  defp handle_command(["help" | _], _) do
    print_help()
  end

  defp handle_command(["list" | _], _) do
    list_workflows()
  end

  defp handle_command(["status", name], _) do
    get_status(name)
  end

  defp handle_command(["stop", name], _) do
    stop_workflow(name)
  end

  defp handle_command(["run", name, file_path], _) do
    run_workflow(name, file_path)
  end

  defp handle_command(["run", _name, _file_path | rest], _) when rest != [] do
    IO.puts("Лишние аргументы: #{inspect(rest)}")
    IO.puts("Использование: run <name> <file_path>")
  end

  defp handle_command(["debug"], _) do
    show_debug_info()
  end

  defp handle_command(_, line) do
    IO.puts("Неизвестная команда: #{line}")
    IO.puts("Введите 'help' для списка команд")
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

      arg ->
        arg
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
    case get_command_action(opts) do
      {:execute, :help} ->
        print_help()
        :ok

      {:execute, :list} ->
        list_workflows()
        :ok

      {:execute, {:status, name}} ->
        get_status(name)
        :ok

      {:execute, {:run, name, file}} ->
        run_workflow(name, file)
        :ok

      {:error, :invalid_args} ->
        print_error("Некорректные аргументы команды", interactive)

      {:error, :unknown_command} ->
        print_error("Неизвестная команда", interactive)

      _ ->
        print_error("Неизвестная команда", interactive)
    end
  end

  defp get_command_action(opts) do
    cond do
      opts[:help] ->
        {:execute, :help}

      opts[:list] ->
        {:execute, :list}

      has_valid_status?(opts) ->
        {:execute, {:status, opts[:status]}}

      has_valid_run?(opts) ->
        {:execute, {:run, opts[:workflow], opts[:file]}}

      has_partial_args?(opts) ->
        {:error, :invalid_args}

      true ->
        {:error, :unknown_command}
    end
  end

  defp has_valid_status?(opts) do
    is_binary(opts[:status]) and opts[:status] != ""
  end

  defp has_valid_run?(opts) do
    is_binary(opts[:workflow]) and is_binary(opts[:file])
  end

  defp has_partial_args?(opts) do
    opts[:status] != nil or opts[:stop] != nil or
      opts[:workflow] != nil or opts[:file] != nil
  end

  defp print_error(message, interactive) do
    if interactive do
      IO.puts("#{message}. Введите 'help' для справки")
    else
      print_help()
    end

    :error
  end

  defp run_workflow(name, file_path) do
    IO.puts("Запуск workflow: #{name} из #{file_path}")

    with {:ok, content} <- File.read(file_path),
         {:ok, workflow} <- Parser.parse_workflow(content),
         {:ok, pid} <- WorkflowExecutor.start_link({name, workflow}) do
      handle_successful_workflow_start(name, pid)
    else
      {:error, reason} ->
        handle_workflow_error(reason)
    end
  end

  defp handle_successful_workflow_start(name, pid) do
    IO.puts("Workflow '#{name}' успешно запущен")
    IO.puts("PID: #{inspect(pid)}")

    Process.sleep(500)
    get_and_display_workflow_status(name)
  end

  defp get_and_display_workflow_status(name) do
    case Registry.lookup(name) do
      [{pid, _}] ->
        status = WorkflowExecutor.get_status(pid)
        print_workflow_details(name, status)

      [] ->
        IO.puts("Workflow не найден в реестре")
    end

    :ok
  end

  defp handle_workflow_error(reason) do
    case reason do
      {:file_error, msg} ->
        IO.puts("Ошибка чтения файла: #{msg}")

      {:parse_error, msg} ->
        IO.puts("Ошибка парсинга Workflow: #{msg}")

      {:execution_error, msg} ->
        IO.puts("Ошибка выполнения Workflow: #{inspect(msg)}")

      _ ->
        IO.puts("Ошибка: #{inspect(reason)}")
    end

    :error
  end

  defp list_workflows() do
    workflows = Registry.list()

    IO.puts("\nЗапущенные workflows:")

    if Enum.empty?(workflows) do
      IO.puts("   Нет запущенных workflows")
    else
      Enum.each(workflows, &print_workflow_status/1)
    end

    :ok
  end

  defp print_workflow_status(%{name: name, pid: pid}) do
    case WorkflowExecutor.get_status(pid) do
      %{status: status, started_at: started_at} ->
        runtime = DateTime.diff(DateTime.utc_now(), started_at)
        IO.puts("   #{name}: #{status} (запущен #{runtime} секунд назад)")

      _ ->
        IO.puts("   #{name}: статус неизвестен")
    end
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
      run <name> <file>    - Запустить workflow
      clear                - Очистить экран
      exit/quit            - Выйти из интерактивного режима

    Примеры:
      run test workflows/test_workflow.yml
      list
      status test
      stop test
    """)
  end

  defp show_debug_info() do
    IO.puts("Отладочная информация:")

    IO.puts(
      "Приложение запущено: #{Application.started_applications() |> Enum.any?(fn {app, _, _} -> app == :fp_lab4 end)}"
    )

    workflows = Registry.list()
    IO.puts("Зарегистрированных workflows: #{length(workflows)}")
    children = Supervisor.which_children(FpLab4.Supervisor)
    IO.puts("Дочерние процессы супервизора: #{length(children)}")
    memory = :erlang.memory()
    IO.puts("Используемая память: #{div(memory[:total], 1024 * 1024)} MB")
  end
end
