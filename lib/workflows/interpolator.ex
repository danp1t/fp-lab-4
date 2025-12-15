defmodule Workflows.Interpolator do
  @moduledoc """
  Модуль для интерполяции значений в строках с использованием контекста.
  Поддерживает:
  - {{variable}} - переменные из контекста
  - \#{function()} - функции (timestamp, current_datetime, random_int и т.д.)
  - Математические выражения в {{...}}
  - Доступ к элементам массива: {{array[0]}}
  - Доступ к полям объектов: {{object.field}} или {{array[0].field}}
  """

  @doc """
  Интерполирует значения в строке, используя контекст
  """
  def interpolate(value, context) when is_binary(value) do
    # Проверяем, не является ли строка исключительно переменной
    trimmed = String.trim(value)

    case Regex.run(~r/^\{\{\s*([^}]+)\s*\}\}$/, trimmed) do
      [_, expr] ->
        # Это выражение целиком, пытаемся получить его значение
        case get_nested_value(expr, context) do
          nil -> ""
          val when is_binary(val) -> val
          val when is_number(val) -> to_string(val)
          val when is_list(val) -> inspect(val)
          val when is_map(val) -> inspect(val)
          val -> inspect(val)
        end
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

  # Интерполяция всех выражений в {{...}} (переменные, пути, математика)
  defp interpolate_expressions(string, context) do
    Regex.replace(~r/\{\{\s*([^}]+)\s*\}\}/, string, fn _match, expr ->
      case evaluate_expression(expr, context) do
        {:ok, result} ->
          to_string(result)
        :error ->
          # Если не удалось вычислить, пытаемся получить как вложенное значение
          case get_nested_value(expr, context) do
            nil -> "{{#{expr}}}"
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
    # Проверяем, является ли выражение математическим (содержит операторы)
    if contains_operator?(expr) do
      evaluate_math_expression(expr, context)
    else
      # Не математическое выражение, просто возвращаем значение
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
      # Заменяем все переменные в выражении на их значения
      expr_with_values = Regex.replace(~r/([a-zA-Z_][a-zA-Z0-9_.\[\]]*)/, expr, fn match, var_path ->
        case get_nested_value(var_path, context) do
          nil -> match  # Оставляем как есть, если не нашли
          value when is_number(value) -> to_string(value)
          _ -> match  # Оставляем как есть для не-чисел
        end
      end)

      # Вычисляем математическое выражение
      {result, _} = Code.eval_string(expr_with_values, [])
      {:ok, result}
    rescue
      _ -> :error
    end
  end

  # Получение вложенного значения по пути типа "all_accounts[0].id"
  defp get_nested_value(path, context) do
    path
    |> String.trim()
    |> String.split(".")
    |> Enum.reduce(context, fn
      segment, acc when is_map(acc) ->
        # Проверяем, содержит ли сегмент доступ к массиву
        case Regex.run(~r/([a-zA-Z_][a-zA-Z0-9_]*)\[(\d+)\]/, segment) do
          [_, array_name, index_str] ->
            # Доступ к элементу массива: array[index]
            array = get_from_context(array_name, acc)
            if is_list(array) do
              index = String.to_integer(index_str)
              if index < length(array), do: Enum.at(array, index), else: nil
            else
              nil
            end
          nil ->
            # Простой доступ к полю
            get_from_context(segment, acc)
        end
      _, _ -> nil
    end)
  end

  defp get_from_context(key, context) do
    # Пробуем получить как атом, потом как строку
    atom_key = String.to_atom(key)
    Map.get(context, atom_key) || Map.get(context, key)
  end

  # Старая функция для обратной совместимости
  defp get_var_value(var_name, context) do
    get_from_context(var_name, context)
  end
end
