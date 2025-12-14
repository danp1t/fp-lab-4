defmodule Workflows.MainSupervisor do
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Workflows.WorkflowDynamicSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_workflow(workflow_name, yaml_content) do
    # Парсим workflow
    case Workflows.Parser.parse_workflow(yaml_content) do
      {:ok, workflow} ->
        # Стартуем workflow executor
        child_spec = {Workflows.WorkflowExecutor, {workflow_name, workflow}}

        case DynamicSupervisor.start_child(
          Workflows.WorkflowDynamicSupervisor,
          child_spec
        ) do
          {:ok, pid} ->
            # Регистрируем в реестре
            Workflows.Registry.register(workflow_name, pid)
            {:ok, pid}
          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
