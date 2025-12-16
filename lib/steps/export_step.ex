defmodule FpLab4.Steps.ExportStep do
  @moduledoc """
  Шаг workflow для экспорта данных.
  Сохраняет результаты в файлы (JSON и другие форматы).
  """

  alias Workflows.Interpolator
  require Logger

  @doc """
  Экспортирует данные в файл
  """
  def save_json(params, context) do
    data = get_input(params["data"], context)
    filename = Interpolator.interpolate(params["filename"], context)
    json_data = Jason.encode!(data, pretty: true)

    case File.write(filename, json_data) do
      :ok ->
        IO.puts("Данные сохранены в: #{filename}")
        context

      {:error, reason} ->
        IO.puts("Произошла ошибка при сохранении данных: #{reason}")
        context
    end
  end

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.to_atom()
    Map.get(context, key)
  end

  defp get_input(<<first::binary-size(2)>> <> _ = value, _context) when first in ["%{", "%["] do
    try do
      {result, _bindings} = Code.eval_string(value)
      result
    rescue
      e ->
        Logger.error("Ошибка преобразования структуры Elixir: #{inspect(e)}")
        value
    end
  end

  defp get_input(value, _context), do: value
end
