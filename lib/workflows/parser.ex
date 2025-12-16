defmodule Workflows.Parser do
  @moduledoc """
  Парсер YAML конфигураций workflow.
  Преобразует YAML-описания workflow во внутренние структуры данных.
  """

  alias Workflows.Step

  @spec parse_workflow(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_workflow(yaml_content) do
    try do
      case YamlElixir.read_from_string(yaml_content) do
        {:ok, data} ->
          workflow = %{
            name: data["name"],
            include_configs: data["include_configs"] || [],
            steps: parse_steps(data["steps"] || []),
            variables: extract_variables(data)
          }

          {:ok, workflow}

        {:error, %YamlElixir.ParsingError{} = error} ->
          {:error, "YAML parsing error: #{error.message}"}

        {:error, reason} ->
          {:error, "Failed to parse YAML: #{inspect(reason)}"}
      end
    rescue
      e ->
        {:error, "Parsing error: #{inspect(e)} - #{Exception.message(e)}"}
    end
  end

  defp parse_steps(steps_data) when is_list(steps_data) do
    Enum.map(steps_data, fn step_data ->
      case step_data["type"] do
        "task" -> parse_task_step(step_data)
        "parallel" -> parse_parallel_step(step_data)
        "sequential" -> parse_sequential_step(step_data)
        # Default to task
        _ -> parse_task_step(step_data)
      end
    end)
  end

  defp parse_task_step(step_data) do
    %Step.Task{
      id: step_data["id"] || generate_id(),
      name: step_data["name"] || step_data["id"],
      type: "task",
      module: step_data["config"]["module"],
      function: step_data["config"]["function"] || "execute",
      method: step_data["config"]["method"],
      url: step_data["config"]["url"],
      headers: step_data["config"]["headers"] || %{},
      body: step_data["config"]["body"],
      parameters: step_data["config"],
      on_success: parse_on_success(step_data["on_success"]),
      on_error: step_data["on_error"]
    }
  end

  defp parse_parallel_step(step_data) do
    %Step.Parallel{
      id: step_data["id"] || generate_id(),
      name: step_data["name"] || step_data["id"],
      type: "parallel",
      steps: parse_steps(step_data["steps"] || []),
      on_success: parse_on_success(step_data["on_success"])
    }
  end

  defp parse_sequential_step(step_data) do
    %Step.Sequential{
      id: step_data["id"] || generate_id(),
      name: step_data["name"] || step_data["id"],
      type: "sequential",
      steps: parse_steps(step_data["steps"] || []),
      on_success: parse_on_success(step_data["on_success"])
    }
  end

  defp parse_on_success(on_success_data) when is_map(on_success_data) do
    Enum.reduce(on_success_data, %{}, fn {key, value}, acc ->
      case key do
        "save_response" -> Map.put(acc, :save_response, value)
        "save_product_id" -> Map.put(acc, :save_product_id, value)
        "save_result" -> Map.put(acc, :save_result, value)
        "save_post_id" -> Map.put(acc, :save_post_id, value)
        _ -> Map.put(acc, String.to_atom(key), value)
      end
    end)
  end

  defp parse_on_success(_), do: %{}

  defp extract_variables(data) do
    variables =
      data["steps"]
      |> List.wrap()
      |> Enum.flat_map(&extract_step_variables/1)
      |> Enum.uniq()

    %{
      declared: variables,
      used: find_variable_usage(data["steps"])
    }
  end

  defp extract_step_variables(step) do
    case step do
      %{"on_success" => on_success} when is_map(on_success) ->
        Enum.map(on_success, fn
          {"save_response", var} -> var
          {"save_product_id", var} -> var
          {"save_result", var} -> var
          _ -> nil
        end)

      _ ->
        []
    end
    |> Enum.reject(&is_nil/1)
  end

  defp find_variable_usage(steps) do
    steps_json = Jason.encode!(steps)

    Regex.scan(~r/\{\{(\w+)\}\}/, steps_json)
    |> Enum.map(fn [_, var] -> var end)
    |> Enum.uniq()
  end

  defp generate_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16()
end
