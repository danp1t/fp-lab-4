defmodule Workflows.Registry do
  @moduledoc """
  Реестр для регистрации и отслеживания запущенных workflow процессов.
  Обеспечивает связь между именами workflow и их PID.
  """

  use GenServer

  defstruct [
    :processes,
    :name_to_pid,
    :pid_to_name
  ]

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register(name, pid) do
    GenServer.call(__MODULE__, {:register, name, pid})
  end

  def lookup(name) do
    GenServer.call(__MODULE__, {:lookup, name})
  end

  def unregister(name) do
    GenServer.call(__MODULE__, {:unregister, name})
  end

  def list() do
    GenServer.call(__MODULE__, :list)
  end

  def whereis(name) do
    GenServer.call(__MODULE__, {:whereis, name})
  end

  # Server Callbacks
  def init(_opts) do
    state = %__MODULE__{
      processes: %{},
      name_to_pid: %{},
      pid_to_name: %{}
    }

    {:ok, state}
  end

  def handle_call({:register, name, pid}, _from, state) do
    # Удаляем старую регистрацию, если существует
    new_state =
      case Map.get(state.name_to_pid, name) do
        nil ->
          state

        old_pid ->
          %{
            state
            | processes: Map.delete(state.processes, old_pid),
              pid_to_name: Map.delete(state.pid_to_name, old_pid)
          }
      end

    new_state = %{
      new_state
      | processes: Map.put(new_state.processes, pid, %{name: name, pid: pid}),
        name_to_pid: Map.put(new_state.name_to_pid, name, pid),
        pid_to_name: Map.put(new_state.pid_to_name, pid, name)
    }

    # Мониторим процесс
    Process.monitor(pid)

    {:reply, :ok, new_state}
  end

  def handle_call({:lookup, name}, _from, state) do
    case Map.get(state.name_to_pid, name) do
      nil -> {:reply, [], state}
      pid -> {:reply, [{pid, name}], state}
    end
  end

  def handle_call({:unregister, name}, _from, state) do
    case Map.get(state.name_to_pid, name) do
      nil ->
        {:reply, :ok, state}

      pid ->
        new_state = %{
          state
          | processes: Map.delete(state.processes, pid),
            name_to_pid: Map.delete(state.name_to_pid, name),
            pid_to_name: Map.delete(state.pid_to_name, pid)
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_call(:list, _from, state) do
    processes = Map.values(state.processes)
    {:reply, processes, state}
  end

  def handle_call({:whereis, name}, _from, state) do
    pid = Map.get(state.name_to_pid, name)
    {:reply, pid, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    case Map.get(state.pid_to_name, pid) do
      nil ->
        {:noreply, state}

      name ->
        new_state = %{
          state
          | processes: Map.delete(state.processes, pid),
            name_to_pid: Map.delete(state.name_to_pid, name),
            pid_to_name: Map.delete(state.pid_to_name, pid)
        }

        {:noreply, new_state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
