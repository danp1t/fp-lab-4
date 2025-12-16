defmodule FpLab4.Steps.DisplayStep do
  @moduledoc """
  Шаг workflow для отображения данных в консоли.
  Форматирует и выводит результаты выполнения workflow.
  """

  def print_summary(params, context) do
    report = get_input(params["report"], context)

    IO.puts("\n" <> String.duplicate("-", 60))
    IO.puts("Результат: ")
    IO.puts(String.duplicate("-", 60))
    print_formatted(report, 0)

    IO.puts(String.duplicate("-", 60))

    context
  end

  defp print_formatted(data, indent) when is_map(data) do
    if map_size(data) == 0 do
      IO.puts(String.duplicate("  ", indent) <> "%{}")
    else
      Enum.each(data, fn {key, value} ->
        IO.write(String.duplicate("  ", indent) <> "#{key}: ")
        print_formatted(value, indent + 1)
      end)
    end
  end

  defp print_formatted(data, indent) when is_list(data) do
    if Enum.empty?(data) do
      IO.puts(String.duplicate("  ", indent) <> "[]")
    else
      IO.puts(String.duplicate("  ", indent) <> "[")

      Enum.each(data, fn item ->
        print_formatted(item, indent + 1)
      end)

      IO.puts(String.duplicate("  ", indent) <> "]")
    end
  end

  defp print_formatted(data, indent) when is_binary(data) do
    IO.puts(String.duplicate("  ", indent) <> "\"#{data}\"")
  end

  defp print_formatted(data, indent) when is_number(data) do
    IO.puts(String.duplicate("  ", indent) <> "#{data}")
  end

  defp print_formatted(data, indent) when is_atom(data) do
    IO.puts(String.duplicate("  ", indent) <> ":#{data}")
  end

  defp print_formatted(data, indent) when is_boolean(data) do
    IO.puts(String.duplicate("  ", indent) <> "#{data}")
  end

  defp print_formatted(data, indent) when is_nil(data) do
    IO.puts(String.duplicate("  ", indent) <> "nil")
  end

  defp print_formatted(data, indent) when is_pid(data) do
    IO.puts(String.duplicate("  ", indent) <> inspect(data))
  end

  defp print_formatted(data, indent) do
    IO.puts(String.duplicate("  ", indent) <> inspect(data))
  end

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.to_atom()
    Map.get(context, key)
  end

  defp get_input(value, _context), do: value
end
