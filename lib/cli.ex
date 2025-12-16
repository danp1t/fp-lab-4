defmodule Workflows.CLI do
  alias Workflows.Parser
  alias Workflows.WorkflowExecutor
  alias Workflows.Registry

  def main(args) do
    Application.ensure_all_started(:fp_lab4)

    args
    |> parse_args()
    |> dispatch_command()
  end

  defp parse_args(args) do
    {opts, args, invalid} = OptionParser.parse(
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

    {opts, args, invalid}
  end

  defp dispatch_command({[help: true], _, _}) do
    print_help()
    :ok
  end

  defp dispatch_command({[workflow: name, file: file_path], _, _}) do
    run_workflow(name, file_path)
  end

  defp dispatch_command({[list: true], _, _}) do
    list_workflows()
  end

  defp dispatch_command({[status: name], _, _}) do
    get_status(name)
  end

  defp dispatch_command({[stop: name], _, _}) do
    stop_workflow(name)
  end

  defp dispatch_command({[], [], []}) do
    print_help()
    :ok
  end

  defp dispatch_command({_, _, invalid}) do
    IO.puts("Неверные аргументы: #{inspect(invalid)}")
    print_help()
    :error
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

                Process.sleep(1000)

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
            IO.puts("   • #{name}: #{status} (запущен #{runtime} секунд назад)")
          _ ->
            IO.puts("   • #{name}: статус неизвестен")
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
      IO.inspect(status.error, label: nil)
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
    🌟 Workflow Orchestration System

    Команды:
      --workflow, -w NAME   Запустить workflow с указанным именем
      --file, -f PATH       Указать файл с workflow (YAML)
      --list, -l            Показать список запущенных workflows
      --status, -s NAME     Показать статус workflow
      --stop NAME           Остановить workflow
      --help, -h            Показать эту справку

    Примеры:
      mix run -e "Workflows.CLI.main(['--help'])"
      mix run -e "Workflows.CLI.main(['--list'])"
      mix run -e "Workflows.CLI.main(['--workflow', 'test', '--file', 'workflows/test.yml'])"

    Сокращения:
      mix run -e "Workflows.CLI.main(['-w', 'test', '-f', 'workflows/test.yml'])"
    """)
  end
end
