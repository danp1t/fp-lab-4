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

    response = make_request(method, url, headers, body)
    handle_response(response)
  end

  defp make_request(:get, url, headers, _body), do: HTTPoison.get(url, headers)

  defp make_request(:post, url, headers, body),
    do: HTTPoison.post(url, Jason.encode!(body), headers)

  defp make_request(:put, url, headers, body),
    do: HTTPoison.put(url, Jason.encode!(body), headers)

  defp make_request(:delete, url, headers, _body), do: HTTPoison.delete(url, headers)

  defp make_request(_method, _url, _headers, _body),
    do: {:error, %HTTPoison.Error{reason: :invalid_method}}

  defp handle_response({:ok, %HTTPoison.Response{status_code: code, body: body}}) do
    handle_status_code(code, body)
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}) do
    Logger.error("HttpStep: HTTP error")
    {:error, "HTTP request failed: #{inspect(reason)}"}
  end

  defp handle_response({:error, reason}) do
    Logger.error("HttpStep: HTTP error")
    {:error, "HTTP request failed: #{inspect(reason)}"}
  end

  defp handle_status_code(code, _body) when code < 200 or code >= 300 do
    Logger.error("HttpStep: Error status #{code}")
    {:error, "HTTP #{code}"}
  end

  defp handle_status_code(_code, body) do
    parse_json_response(body)
  end

  defp parse_json_response(body) do
    case Jason.decode(body) do
      {:ok, parsed_body} ->
        Logger.info("HttpStep: Success! Returning data")
        parsed_body

      {:error, error} ->
        Logger.error("HttpStep: Failed to parse JSON")
        {:error, "Failed to parse JSON: #{inspect(error)}"}
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
