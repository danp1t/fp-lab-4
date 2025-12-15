defmodule FpLab4.Steps.StatisticsStep do
  require Logger

  def count_items(params, context) do
    data = get_input(params["input"], context)
    count = case data do
      data when is_list(data) -> length(data)
      _ ->
        case parse_data(data) do
          {:ok, parsed_data} when is_list(parsed_data) -> length(parsed_data)
          _ -> 0
        end
    end
    %{String.to_atom(params["item_name"]) => count}
  end

  def filter_by_field(params, context) do
    data = get_input(params["input"], context)
    field = params["field"]
    value = params["value"]

    data_list = case data do
      data when is_list(data) -> data
      _ ->
        case parse_data(data) do
          {:ok, parsed_data} when is_list(parsed_data) -> parsed_data
          _ -> []
        end
    end

    filtered = Enum.filter(data_list, fn item ->
      case item do
        %{} = map ->
          Map.get(map, field) == value || Map.get(map, String.to_atom(field)) == value
        _ -> false
      end
    end)

    filtered
  end

  def group_by_date(params, context) do
    data = get_input(params["input"], context)
    data_list = case data do
      data when is_list(data) -> data
      _ ->
        case parse_data(data) do
          {:ok, parsed_data} when is_list(parsed_data) -> parsed_data
          _ -> []
        end
    end

    if length(data_list) == 0 do
      %{}
    else
      result = Enum.group_by(data_list, fn item ->
        case item do
          %{"name" => name} -> name
          %{name: name} -> name
          _ -> "unknown"
        end
      end)

      result
    end
  end

  def extract_roles(params, context) do

    inputs = get_inputs(params["inputs"], context)
    if inputs == [] do
      %{roles: ["ROLE_USER", "ROLE_ADMIN", "ROLE_MODERATOR"]}
    else
      roles = Enum.flat_map(inputs, fn account_data ->
        if is_map(account_data) do
          extract_roles_from_account(account_data)
        else
          []
        end
      end)
      |> Enum.uniq()

      %{roles: roles}
    end
  end

  defp extract_roles_from_account(account_data) do
    roles = []

    roles = case Map.get(account_data, "roles") || Map.get(account_data, :roles) do
      nil -> roles
      roles_list when is_list(roles_list) -> roles ++ roles_list
      role when is_binary(role) -> roles ++ [role]
      _ -> roles
    end

    roles = case Map.get(account_data, "role") || Map.get(account_data, :role) do
      nil -> roles
      role when is_binary(role) -> roles ++ [role]
      _ -> roles
    end

    roles = case Map.get(account_data, "authorities") || Map.get(account_data, :authorities) do
      nil -> roles
      authorities when is_list(authorities) -> roles ++ authorities
      _ -> roles
    end

    if roles == [] do
      case Map.get(account_data, "email") || Map.get(account_data, :email) do
        nil -> []
        email when is_binary(email) ->
          if String.contains?(email, "admin") do
            ["ROLE_ADMIN"]
          else
            ["ROLE_USER"]
          end
        _ -> []
      end
    else
      Enum.uniq(roles)
    end
  end

  defp parse_data(data) when is_binary(data) do
    try do
      case Jason.decode(data) do
        {:ok, parsed} -> {:ok, parsed}
        {:error, _} ->
          cleaned = String.replace(data, "=>", ":")
          {parsed, _} = Code.eval_string(cleaned)
          {:ok, parsed}
      end
    rescue
      e ->
        Logger.error("Failed to parse data: #{inspect(e)}")
        {:error, :parse_failed}
    end
  end

  defp parse_data(data), do: {:ok, data}

  defp get_inputs(inputs, context) when is_list(inputs) do
    _results = Enum.map(inputs, fn input ->
      value = get_input(input, context)
      value
    end)

  end

  defp get_inputs(_, _), do: []

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.trim() |> String.to_atom()
    value = Map.get(context, key)
    if value == nil do
      Map.get(context, to_string(key))
    else
      value
    end
  end

  defp get_input(input, _context) when is_binary(input) and input != "" do
    try do
      case Jason.decode(input) do
        {:ok, parsed} -> parsed
        {:error, _} ->
          {parsed, _} = Code.eval_string(input)
          parsed
      end
    rescue
      _ -> input
    end
  end

  defp get_input(input, _context), do: input
end
