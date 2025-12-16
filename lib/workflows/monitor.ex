defmodule Workflows.Monitor do
  use GenServer

  require Logger

  @refresh_interval 5000

  defstruct [
    :workflows,
    :metrics,
    :started_at
  ]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end

  def get_workflow_status(name) do
    case Workflows.Registry.lookup(name) do
      [{pid, _}] ->
        {:ok, Workflows.WorkflowExecutor.get_status(pid)}

      [] ->
        {:error, :not_found}
    end
  end

  def init(_opts) do
    state = %__MODULE__{
      workflows: %{},
      metrics: %{
        total_executed: 0,
        successful: 0,
        failed: 0,
        running: 0
      },
      started_at: DateTime.utc_now()
    }

    schedule_refresh()

    {:ok, state}
  end

  def handle_call(:get_stats, _from, state) do
    stats = calculate_current_stats(state)
    {:reply, stats, state}
  end

  def handle_info(:refresh, state) do
    stats = calculate_current_stats(state)
    schedule_refresh()
    {:noreply, %{state | metrics: stats}}
  end

  defp calculate_current_stats(state) do
    workflows = Workflows.Registry.list()

    running =
      workflows
      |> Enum.filter(fn %{pid: pid} ->
        case Workflows.WorkflowExecutor.get_status(pid) do
          %{status: :running} -> true
          _ -> false
        end
      end)
      |> length()

    %{
      running: running,
      total_executed: length(workflows),
      successful: 0,
      failed: 0,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }
  end

  defp schedule_refresh() do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
