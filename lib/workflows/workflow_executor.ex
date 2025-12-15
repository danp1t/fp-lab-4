defmodule Workflows.WorkflowExecutor do
  use GenServer

  require Logger

  alias Workflows.ConfigManager
  alias Workflows.Interpolator

  defstruct [
    :workflow_name,
    :workflow,
    :configs,
    :context,
    :status,
    :results,
    :started_at,
    :completed_at,
    :error,
    :retry_count
  ]

  # Client API
  def start_link({name, workflow}) do
    GenServer.start_link(__MODULE__, {name, workflow})
  end

  def get_status(pid) do
    GenServer.call(pid, :get_status)
  end

  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # Server Callbacks
  def init({name, workflow}) do
    Logger.info("Starting workflow: #{name}")

    # Регистрируем процесс
    case Workflows.Registry.register(name, self()) do
      :ok -> Logger.debug("Registered workflow: #{name}")
      {:error, reason} -> Logger.warn("Failed to register workflow: #{reason}")
    end

    # Загружаем конфигурации
    configs = ConfigManager.load_configs(workflow.include_configs)

    # Инициализируем контекст
    initial_context = ConfigManager.merge_contexts(configs, %{
      workflow_name: name,
      started_at: DateTime.utc_now(),
      timestamp: DateTime.utc_now() |> DateTime.to_unix(),
      current_datetime: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    state = %__MODULE__{
      workflow_name: name,
      workflow: workflow,
      configs: configs,
      context: initial_context,
      status: :initialized,
      results: %{},
      started_at: DateTime.utc_now(),
      retry_count: 0
    }

    {:ok, state, {:continue, :execute}}
  end

  def handle_continue(:execute, state) do
    new_state =
      state
      |> Map.put(:status, :running)
      |> execute_workflow()

    {:noreply, new_state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:retry_workflow, state) when state.retry_count < 3 do
    Logger.info("Retrying workflow #{state.workflow_name}, attempt #{state.retry_count + 1}")

    new_state = %{state |
      status: :retrying,
      retry_count: state.retry_count + 1
    }
    |> execute_workflow()

    {:noreply, new_state}
  end

  def handle_info(:retry_workflow, state) do
    Logger.error("Max retries reached for workflow #{state.workflow_name}")
    {:stop, :normal, %{state | status: :failed}}
  end

  def terminate(reason, state) do
    Logger.info("Workflow #{state.workflow_name} terminating: #{inspect(reason)}")
    Workflows.Registry.unregister(state.workflow_name)
    :ok
  end

  defp execute_workflow(state) do
    try do
      Logger.info("Executing workflow steps for #{state.workflow_name}")

      # Выполняем шаги
      new_context = execute_steps(state.workflow.steps, state.context)

      %{state |
        status: :completed,
        context: new_context,
        completed_at: DateTime.utc_now(),
        results: Map.put(state.results, :final, new_context)
      }
    rescue
      error ->
        Logger.error("Workflow execution failed: #{inspect(error)}")

        error_state = %{state |
          status: :failed,
          error: %{
            message: Exception.message(error),
            stacktrace: Exception.format_stacktrace(__STACKTRACE__),
            time: DateTime.utc_now()
          }
        }

        # Планируем повторную попытку
        Process.send_after(self(), :retry_workflow, 5000)

        error_state
    catch
      :exit, reason ->
        Logger.error("Workflow exited: #{inspect(reason)}")
        %{state | status: :exited, error: reason}
    end
  end

  defp execute_steps(steps, context) when is_list(steps) do
    Enum.reduce(steps, context, &execute_step/2)
  end

  defp execute_step(step, context) do
    Logger.debug("Executing step: #{step.name || step.id}")

    result = case step do
      %Workflows.Step.Task{} = task ->
        execute_task(task, context)

      %Workflows.Step.Parallel{} = parallel ->
        execute_parallel(parallel, context)

      %Workflows.Step.Sequential{} = sequential ->
        execute_sequential(sequential, context)
    end

    # Передаем контекст в handle_step_result
    handle_step_result(result, step.on_success || %{}, context)
  end

  defp execute_task(task, context) do
    # Интерполируем параметры
    interpolated_params = Interpolator.interpolate(task.parameters, context)

    Logger.debug("Task #{task.name} params: #{inspect(interpolated_params, limit: 2)}")

    # Определяем модуль и функцию
    module = task.module |> String.split(".") |> Module.concat()
    function = task.function |> String.to_atom()

    # Выполняем шаг
    result = apply(module, function, [interpolated_params, context])

    Logger.debug("Task #{task.name} result type: #{inspect(result, limit: 2)}")

    # Обрабатываем результат
    case result do
      {:error, error} ->
        Logger.error("Task #{task.name} failed: #{error}")
        {:error, error}
      data ->
        # Любые данные (список, мапа, число, строка)
        {:ok, data}
    end
  end

  defp execute_parallel(parallel, context) do
  Logger.info("Executing parallel steps: #{length(parallel.steps)} tasks")
  Logger.info("Initial context keys: #{inspect(Map.keys(context))}")  # Исправить здесь

  tasks = Enum.map(parallel.steps, fn step ->
    Task.async(fn -> execute_step(step, context) end)
  end)

  results = Task.await_many(tasks, 30_000)

  # Добавим логирование результатов
  Logger.info("Parallel results count: #{length(results)}")
  Enum.each(results, fn result ->
    case result do
      {:ok, data} when is_map(data) ->
        Logger.info("Result keys: #{inspect(Map.keys(data))}")  # И здесь
      {:error, error} ->
        Logger.error("Error in parallel step: #{error}")
      other ->
        Logger.info("Other result type: #{inspect(other, limit: 1)}")
    end
  end)

  # Объединяем результаты (контексты) от всех шагов
  merged_context = Enum.reduce(results, context, fn
    {:ok, step_context}, acc when is_map(step_context) ->
      Logger.info("Merging step context with keys: #{inspect(Map.keys(step_context))}")  # И здесь
      Map.merge(acc, step_context)

    {:error, error}, acc ->
      Logger.warning("Parallel step failed: #{error}")
      acc

    step_context, acc when is_map(step_context) ->
      Logger.info("Merging non-tuple step context with keys: #{inspect(Map.keys(step_context))}")  # И здесь
      Map.merge(acc, step_context)

    other, acc ->
      Logger.warning("Unexpected result in parallel: #{inspect(other, limit: 1)}")
      acc
  end)

  Logger.info("Merged context keys after parallel: #{inspect(Map.keys(merged_context))}")  # И здесь
  merged_context
end

  defp execute_sequential(sequential, context) do
    Logger.info("Executing sequential steps: #{length(sequential.steps)} steps")
    execute_steps(sequential.steps, context)
  end

  # Обработка результатов шага
  defp handle_step_result({:ok, data}, on_success, context) do
    Logger.debug("Handling step result with on_success: #{inspect(on_success)}")

    # Сохраняем результат в контекст
    new_context = Enum.reduce(on_success, context, fn
      {:save_response, key}, acc ->
        Logger.debug("Saving response as #{key}: #{inspect(data, limit: 1)}")
        # Сохраняем как атом
        Map.put(acc, String.to_atom(key), data)

      {:save_result, key}, acc ->
        Logger.debug("Saving result as #{key}: #{inspect(data, limit: 1)}")
        Map.put(acc, String.to_atom(key), data)

      {:save_product_id, key}, acc ->
        id = if is_map(data), do: data["id"] || data[:id], else: data
        Map.put(acc, String.to_atom(key), id)

      {:save_post_id, key}, acc ->
        id = if is_map(data), do: data["id"] || data[:id], else: data
        Map.put(acc, String.to_atom(key), id)

      _, acc -> acc
    end)

    Logger.debug("Context keys after save: #{inspect(Map.keys(new_context), limit: 10)}")
    new_context
  end

  defp handle_step_result({:error, error}, _, _) do
    Logger.error("Step failed: #{error}")
    throw({:step_failed, error})
  end

  defp handle_step_result(other, on_success, context) do
    # Если результат не кортеж {:ok, data} или {:error, error}, считаем его успешным
    Logger.debug("Handling non-tuple result: #{inspect(other, limit: 1)}")

    # Если результат уже контекст (map с ключами), возвращаем его как есть
    if is_map(other) and Map.has_key?(other, :timestamp) and Map.has_key?(other, :workflow_name) do
      Logger.debug("Result is already a context, returning as is")
      other
    else
      # Иначе обрабатываем как обычный результат
      handle_step_result({:ok, other}, on_success, context)
    end
  end
end
