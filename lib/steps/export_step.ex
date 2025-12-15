defmodule FpLab4.Steps.ExportStep do
  alias Workflows.Interpolator
  require Logger

  @doc """
  Экспортирует данные в различные форматы
  """
  def save_json(params, context) do
    data = get_input(params["data"], context)
    filename = Interpolator.interpolate(params["filename"], context)

    Logger.debug("Data type before encoding: #{inspect(data |> Map.get(:__struct__) || "plain")}")

    json_data = Jason.encode!(data, pretty: true)

    case File.write(filename, json_data) do
      :ok ->
        IO.puts("✅ Data exported to #{filename}")
        context

      {:error, reason} ->
        IO.puts("❌ Failed to export data: #{reason}")
        context
    end
  end

  def save_csv(params, context) do
    data = get_input(params["data"], context)
    filename = Interpolator.interpolate(params["filename"], context)

    csv_content = convert_to_csv(data)

    case File.write(filename, csv_content) do
      :ok ->
        IO.puts("✅ CSV exported to #{filename}")
        context

      {:error, reason} ->
        IO.puts("❌ Failed to export CSV: #{reason}")
        context
    end
  end

  defp convert_to_csv(data) when is_list(data) do
    if length(data) > 0 do
      headers = data |> hd |> Map.keys() |> Enum.join(",")
      rows = Enum.map(data, fn row ->
        Map.values(row) |> Enum.map(&to_string/1) |> Enum.join(",")
      end)

      [headers | rows] |> Enum.join("\n")
    else
      ""
    end
  end

  # Обработка ссылок на контекст в формате {{key}}
  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.to_atom()
    Map.get(context, key)
  end

  # Обработка уже сериализованных Elixir-термов (строк, начинающихся с %{)
  defp get_input(<<first::binary-size(2)>> <> _ = value, context) when first in ["%{", "%["] do
    try do
      # Пытаемся распарсить Elixir-терм из строки
      {result, _bindings} = Code.eval_string(value)
      result
    rescue
      e ->
        Logger.error("Failed to parse Elixir term: #{inspect(e)}")
        # Если не удалось распарсить, возвращаем как есть
        value
    end
  end

  # Обработка простых значений
  defp get_input(value, _context), do: value
end
