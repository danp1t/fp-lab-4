defmodule FpLab4.Steps.HttpStep do
  @moduledoc """
  Шаг workflow для выполнения HTTP запросов.
  Поддерживает GET, POST, PUT, DELETE методы и интерполяцию параметров.
  """

  alias HTTPoison

  require Logger

  def execute(params, context) do
    Logger.info("HttpStep: Starting execution")

    method = params["method"] |> String.downcase() |> String.to_atom()
    url = interpolate(params["url"], context)
    headers = interpolate(params["headers"], context)
    body = interpolate(params["body"], context)

    Logger.info("HttpStep: Making #{method} request to #{url}")

    response =
      case method do
        :get -> HTTPoison.get(url, headers)
        :post -> HTTPoison.post(url, Jason.encode!(body), headers)
        :put -> HTTPoison.put(url, Jason.encode!(body), headers)
        :delete -> HTTPoison.delete(url, headers)
      end

    Logger.info("HttpStep: Response received")

    case response do
      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 200..299 ->
        case Jason.decode(body) do
          {:ok, parsed_body} ->
            Logger.info("HttpStep: Success! Returning data")
            parsed_body

          {:error, error} ->
            Logger.error("HttpStep: Failed to parse JSON")
            {:error, "Failed to parse JSON: #{inspect(error)}"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("HttpStep: Error status #{code}")
        {:error, "HTTP #{code}: #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HttpStep: HTTP error")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp interpolate(value, context) when is_binary(value) do
    Regex.replace(~r/\{\{(\w+)\}\}/, value, fn _, key ->
      case Map.get(context, String.to_atom(key)) do
        nil -> Map.get(context, key)
        val -> to_string(val)
      end
    end)
  end

  defp interpolate(map, context) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      Map.put(acc, k, interpolate(v, context))
    end)
  end

  defp interpolate(list, context) when is_list(list) do
    Enum.map(list, &interpolate(&1, context))
  end

  defp interpolate(value, _context), do: value
end
