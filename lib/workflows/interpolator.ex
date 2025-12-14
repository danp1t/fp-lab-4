defmodule Workflows.Interpolator do
  @moduledoc """
  Модуль для интерполяции значений в строках с использованием контекста.
  Поддерживает:
  - {{variable}} - переменные из контекста
  - \#{function()} - функции (timestamp, current_datetime, random_int и т.д.)
  - Математические выражения в {{...}}
  """

  @doc """
  Интерполирует значения в строке, используя контекст
  """
  def interpolate(value, context) when is_binary(value) do
    # Проверяем, не является ли строка исключительно переменной
    trimmed = String.trim(value)

    case Regex.run(~r/^\{\{\s*(\w+)\s*\}\}$/, trimmed) do
      [_, var_name] ->
        # Это переменная целиком, возвращаем значение как есть
        get_var_value(var_name, context)
      _ ->
        # Иначе интерполируем как обычную строку
        interpolate_string(value, context)
    end
  end

  def interpolate(value, context) when is_map(value) do
    Enum.reduce(value, %{}, fn {k, v}, acc ->
      Map.put(acc, k, interpolate(v, context))
    end)
  end

  def interpolate(value, context) when is_list(value) do
    # Для списков интерполируем только строки и мапы
    Enum.map(value, fn
      item when is_binary(item) -> interpolate(item, context)
      item when is_map(item) -> interpolate(item, context)
      item -> item
    end)
  end

  def interpolate(value, _context), do: value

  # Интерполяция всей строки
  defp interpolate_string(string, context) do
    string
    |> interpolate_functions()
    |> interpolate_expressions(context)
    |> interpolate_variables(context)
  end

  # Интерполяция функций типа #{timestamp}
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
    {:ok, :rand.uniform(1000000)}
  end

  defp parse_function_call(func_call) do
    # Поддержка функций с аргументами
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

  # Интерполяция математических выражений в {{...}}
  defp interpolate_expressions(string, context) do
    Regex.replace(~r/\{\{\s*([^}]+)\s*\}\}/, string, fn _match, expr ->
      case evaluate_expression(expr, context) do
        {:ok, result} -> to_string(result)
        :error -> "{{#{expr}}}"
      end
    end)
  end

  defp evaluate_expression(expr, context) do
    try do
      # Заменяем переменные на их значения
      expr_with_values = Regex.replace(~r/\b(\w+)\b/, expr, fn _match, var_name ->
        case get_var_value(var_name, context) do
          nil -> var_name
          value when is_number(value) -> to_string(value)
          value -> inspect(value)
        end
      end)

      # Вычисляем выражение (только безопасные математические операции)
      {result, _} = Code.eval_string(expr_with_values, [])
      {:ok, result}
    rescue
      _ -> :error
    end
  end

  defp get_var_value(var_name, context) do
    # Пробуем получить как атом, потом как строку
    case Map.get(context, String.to_atom(var_name)) do
      nil -> Map.get(context, var_name)
      value -> value
    end
  end

  # Интерполяция простых переменных {{variable}}
  defp interpolate_variables(string, context) do
    Regex.replace(~r/\{\{(\w+)\}\}/, string, fn _match, var_name ->
      value = get_var_value(var_name, context)

      case value do
        nil -> ""
        value when is_binary(value) -> value
        value when is_number(value) -> to_string(value)
        value when is_list(value) -> inspect(value)
        value when is_map(value) -> inspect(value)
        {:ok, data} -> to_string(data)
        _ -> inspect(value)
      end
    end)
  end
end
