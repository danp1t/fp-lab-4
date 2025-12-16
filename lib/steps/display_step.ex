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

    IO.inspect(report, limit: :infinity)
    IO.puts(String.duplicate("-", 60))

    context
  end

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.to_atom()
    Map.get(context, key)
  end

  defp get_input(value, _context), do: value
end
