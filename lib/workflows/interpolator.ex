defmodule Workflows.Interpolator do
  def interpolate(value, context) when is_binary(value) do
    trimmed = String.trim(value)

    case Regex.run(~r/^\{\{\s*([^}]+)\s*\}\}$/, trimmed) do
      [_, expr] ->
        case get_nested_value(expr, context) do
          nil -> ""
          val when is_binary(val) -> val
          val when is_number(val) -> to_string(val)
          val when is_list(val) -> inspect(val)
          val when is_map(val) -> inspect(val)
          val -> inspect(val)
        end

      _ ->
        interpolate_string(value, context)
    end
  end

  def interpolate(value, context) when is_map(value) do
    Enum.reduce(value, %{}, fn {k, v}, acc ->
      Map.put(acc, k, interpolate(v, context))
    end)
  end

  def interpolate(value, context) when is_list(value) do
    Enum.map(value, fn
      item when is_binary(item) -> interpolate(item, context)
      item when is_map(item) -> interpolate(item, context)
      item -> item
    end)
  end

  def interpolate(value, _context), do: value

  defp interpolate_string(string, context) do
    string
    |> interpolate_functions()
    |> interpolate_expressions(context)
  end

  defp interpolate_functions(string) do
    Regex.replace(~r/#\{([^}]+)\}/, string, fn _match, func_call ->
      case parse_function_call(func_call) do
        {:ok, result} -> to_string(result)
        :error -> ""
      end
    end)
  end

  defp parse_function_call("timestamp") do
    {:ok, DateTime.utc_now() |> DateTime.to_unix()}
  end

  defp parse_function_call("current_datetime") do
    {:ok, DateTime.utc_now() |> DateTime.to_iso8601()}
  end

  defp parse_function_call("random_int") do
    {:ok, :rand.uniform(1_000_000)}
  end

  defp parse_function_call(func_call) do
    case String.split(func_call, ["(", ")"], parts: 2) do
      [func_name, arg_string] ->
        args = String.split(arg_string, ",") |> Enum.map(&String.trim/1)
        execute_function(func_name, args)

      _ ->
        :error
    end
  end

  defp execute_function("add", [a, b]) do
    with {a_int, _} <- Integer.parse(a),
         {b_int, _} <- Integer.parse(b) do
      {:ok, a_int + b_int}
    else
      _ -> :error
    end
  end

  defp execute_function("multiply", [a, b]) do
    with {a_int, _} <- Integer.parse(a),
         {b_int, _} <- Integer.parse(b) do
      {:ok, a_int * b_int}
    else
      _ -> :error
    end
  end

  defp execute_function(_, _), do: :error

  defp interpolate_expressions(string, context) do
    Regex.replace(~r/\{\{\s*([^}]+)\s*\}\}/, string, fn _match, expr ->
      case evaluate_expression(expr, context) do
        {:ok, result} ->
          to_string(result)

        :error ->
          case get_nested_value(expr, context) do
            nil ->
              "{{#{expr}}}"

            value ->
              case value do
                v when is_binary(v) -> v
                v when is_number(v) -> to_string(v)
                v when is_list(v) -> inspect(v)
                v when is_map(v) -> inspect(v)
                v -> inspect(v)
              end
          end
      end
    end)
  end

  defp evaluate_expression(expr, context) do
    if contains_operator?(expr) do
      evaluate_math_expression(expr, context)
    else
      case get_nested_value(expr, context) do
        nil -> :error
        value -> {:ok, value}
      end
    end
  end

  defp contains_operator?(expr) do
    Regex.match?(~r/[\+\-\*\/]/, expr)
  end

  defp evaluate_math_expression(expr, context) do
    try do
      expr_with_values =
        Regex.replace(~r/([a-zA-Z_][a-zA-Z0-9_.\[\]]*)/, expr, fn match, var_path ->
          case get_nested_value(var_path, context) do
            nil -> match
            value when is_number(value) -> to_string(value)
            _ -> match
          end
        end)

      {result, _} = Code.eval_string(expr_with_values, [])
      {:ok, result}
    rescue
      _ -> :error
    end
  end

  defp get_nested_value(path, context) do
    path
    |> String.trim()
    |> String.split(".")
    |> Enum.reduce(context, fn
      segment, acc when is_map(acc) ->
        case Regex.run(~r/([a-zA-Z_][a-zA-Z0-9_]*)\[(\d+)\]/, segment) do
          [_, array_name, index_str] ->
            array = get_from_context(array_name, acc)

            if is_list(array) do
              index = String.to_integer(index_str)
              if index < length(array), do: Enum.at(array, index), else: nil
            else
              nil
            end

          nil ->
            get_from_context(segment, acc)
        end

      _, _ ->
        nil
    end)
  end

  defp get_from_context(key, context) do
    atom_key = String.to_atom(key)
    Map.get(context, atom_key) || Map.get(context, key)
  end
end
