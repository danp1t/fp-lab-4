defmodule Workflows.WorkflowSupervisor do
  @moduledoc """
  Супервизор для управления динамическими workflow процессами.
  """
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
end
