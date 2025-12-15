defmodule FpLab4.CLI do
  alias Workflows.MainSupervisor
  alias Workflows.Parser

  def main(args) do
    args
    |> parse_args()
    |> process_command()
  end

  defp parse_args(args) do
    {opts, parsed_args, _} = OptionParser.parse(args,
      strict: [
        workflow: :string,
        file: :string,
        list: :boolean,
        status: :string,
        stop: :string
      ]
    )

    {opts, parsed_args}
  end

  defp process_command({[workflow: name, file: file_path], _}) do
    IO.puts("Starting workflow: #{name} from #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        case Parser.parse_workflow(content) do
          {:ok, workflow} ->
            case MainSupervisor.start_workflow(name, workflow) do
              {:ok, pid} ->
                IO.puts("Workflow #{name} запущен и имеет PID: #{inspect(pid)}")
                :timer.sleep(1000)
                print_workflow_status(name)
                :ok
              {:error, reason} ->
                IO.puts("Ошибка выполнения Workflow: #{reason}")
                :error
            end
          {:error, reason} ->
            IO.puts("Ошибка парсинга Workflow: #{reason}")
            :error
        end
      {:error, reason} ->
        IO.puts("Ошибка чтения данных: #{reason}")
        :error
    end
  end

  defp process_command({[list: true], _}) do
    IO.puts("Выполняющиеся workflows:")
    IO.puts(String.duplicate("=", 50))

    workflows = Workflows.Registry.list()

    if length(workflows) > 0 do
      Enum.each(workflows, fn %{name: name, pid: pid} ->
        case Workflows.WorkflowExecutor.get_status(pid) do
          %{status: status, started_at: started} ->
            runtime = DateTime.diff(DateTime.utc_now(), started)
            IO.puts("  #{name}: #{status} (running #{runtime}s)")
          _ ->
            IO.puts("  #{name}: unknown")
        end
      end)
    else
      IO.puts("  No workflows running")
    end

    IO.puts(String.duplicate("=", 50))
    :ok
  end

  defp process_command({[status: name], _}) do
    print_workflow_status(name)
  end

  defp process_command({[stop: name], _}) do
    case Workflows.Registry.lookup(name) do
      [{pid, _}] ->
        case Workflows.WorkflowExecutor.stop(pid) do
          :ok ->
            IO.puts("Workflow #{name} остановлен")
            :ok
          {:error, reason} ->
            IO.puts("Ошибка остановки Workflow: #{reason}")
            :error
        end
      [] ->
        IO.puts("Workflow #{name} не найден")
        :error
    end
  end

  defp process_command(_) do
    IO.puts("""
    Workflow Orchestration System

    Usage:
      mix run lib/cli.exs --workflow NAME --file PATH
      mix run lib/cli.exs --list
      mix run lib/cli.exs --status NAME
      mix run lib/cli.exs --stop NAME

    Examples:
      mix run lib/cli.exs --workflow add_product --file workflows/add_product_workflow.yml
      mix run lib/cli.exs --list
    """)
    :ok
  end

  defp print_workflow_status(name) do
    case Workflows.Registry.lookup(name) do
      [{pid, _}] ->
        status = Workflows.WorkflowExecutor.get_status(pid)
        IO.puts("Статус #{name}:")
        IO.puts(String.duplicate("-", 40))
        IO.inspect(status, limit: :infinity)
        :ok
      [] ->
        IO.puts("Workflow #{name} не найден")
        :error
    end
  end
end
