defmodule FpLab4.Steps.StatisticsStep do
  @moduledoc """
  Шаг workflow для статистической обработки данных.
  Поддерживает подсчет, фильтрацию, сортировку и группировку данных.
  """

  require Logger

  def count_items(params, context) do
    data = get_input(params["input"], context)
    count = calculate_count(data)
    %{String.to_atom(params["item_name"]) => count}
  end

  def get_latest(params, context) do
    data = get_input(params["input"], context)
    date_field = params["date_field"]

    data_list = ensure_list(data)

    if Enum.empty?(data_list) do
      %{}
    else
      find_latest_item(data_list, date_field)
    end
  end

  def get_top_n(params, context) do
    data = get_input(params["input"], context)
    field = params["field"]
    n = parse_n_param(params["n"])

    data_list = ensure_list(data)

    if Enum.empty?(data_list) do
      []
    else
      sort_and_take_top_n(data_list, field, n)
    end
  end

  def filter_by_field(params, context) do
    data = get_input(params["input"], context)
    field = params["field"]
    value = params["value"]

    data_list = ensure_list(data)
    filter_data_list(data_list, field, value)
  end

  def group_by_date(params, context) do
    data = get_input(params["input"], context)
    data_list = ensure_list(data)

    if Enum.empty?(data_list) do
      %{}
    else
      group_data_by_name(data_list)
    end
  end

  def extract_roles(params, context) do
    inputs = get_inputs(params["inputs"], context)

    if Enum.empty?(inputs) do
      %{roles: ["ROLE_USER", "ROLE_ADMIN", "ROLE_MODERATOR"]}
    else
      roles = extract_all_roles(inputs)
      %{roles: Enum.uniq(roles)}
    end
  end

  # Вспомогательные функции

  defp calculate_count(data) when is_list(data), do: length(data)

  defp calculate_count(data) do
    case parse_data(data) do
      {:ok, parsed_data} when is_list(parsed_data) -> length(parsed_data)
      _ -> 0
    end
  end

  defp find_latest_item(data_list, date_field) do
    sorted_list =
      Enum.sort_by(
        data_list,
        fn item -> parse_date_from_item(item, date_field) end,
        &>=/2
      )

    List.first(sorted_list) || %{}
  end

  defp sort_and_take_top_n(data_list, field, n) do
    data_list
    |> Enum.sort_by(&get_field_value(&1, field), &>=/2)
    |> Enum.take(n)
  end

  defp filter_data_list(data_list, field, value) do
    Enum.filter(data_list, fn item ->
      matches_field?(item, field, value)
    end)
  end

  defp group_data_by_name(data_list) do
    Enum.group_by(data_list, &extract_name/1)
  end

  defp extract_all_roles(inputs) do
    inputs
    |> Enum.filter(&is_map/1)
    |> Enum.flat_map(&extract_roles_from_account/1)
  end

  defp extract_roles_from_account(account_data) do
    roles = []
    roles = add_roles(roles, account_data, "roles")
    roles = add_roles(roles, account_data, :roles)
    roles = add_roles(roles, account_data, "role")
    roles = add_roles(roles, account_data, :role)
    roles = add_roles(roles, account_data, "authorities")
    roles = add_roles(roles, account_data, :authorities)

    if roles == [] do
      infer_roles_from_email(account_data)
    else
      roles
    end
  end

  defp add_roles(roles, account_data, key) do
    case Map.get(account_data, key) do
      nil -> roles
      roles_list when is_list(roles_list) -> roles ++ roles_list
      role when is_binary(role) -> roles ++ [role]
      _ -> roles
    end
  end

  defp infer_roles_from_email(account_data) do
    email = Map.get(account_data, "email") || Map.get(account_data, :email)

    cond do
      is_nil(email) -> []
      is_binary(email) and email =~ "admin" -> ["ROLE_ADMIN"]
      is_binary(email) -> ["ROLE_USER"]
      true -> []
    end
  end

  defp parse_n_param(n) when is_integer(n), do: n

  defp parse_n_param(n) when is_binary(n) do
    case Integer.parse(n) do
      {num, _} -> num
      :error -> 5
    end
  end

  defp parse_n_param(_), do: 5

  defp ensure_list(data) when is_list(data), do: data

  defp ensure_list(data) do
    case parse_data(data) do
      {:ok, parsed_data} when is_list(parsed_data) -> parsed_data
      _ -> []
    end
  end

  defp get_field_value(item, field) do
    value = Map.get(item, field) || Map.get(item, String.to_atom(field)) || 0

    case value do
      val when is_integer(val) -> val
      val when is_binary(val) -> parse_integer(val)
      _ -> 0
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_date_from_item(item, date_field) do
    date_str = Map.get(item, date_field) || Map.get(item, String.to_atom(date_field)) || ""
    parse_date_to_seconds(date_str)
  end

  defp parse_date_to_seconds(date_str) when is_binary(date_str) do
    case DateTime.from_iso8601(date_str) do
      {:ok, dt, _} -> DateTime.to_unix(dt)
      {:error, _} -> 0
    end
  end

  defp parse_date_to_seconds(_), do: 0

  defp matches_field?(item, field, value) do
    case item do
      %{} = map ->
        Map.get(map, field) == value || Map.get(map, String.to_atom(field)) == value

      _ ->
        false
    end
  end

  defp extract_name(item) do
    case item do
      %{"name" => name} -> name
      %{name: name} -> name
      _ -> "unknown"
    end
  end

  defp parse_data(data) when is_binary(data) do
    try do
      case Jason.decode(data) do
        {:ok, parsed} -> {:ok, parsed}
        {:error, _} -> parse_ruby_style_data(data)
      end
    rescue
      e ->
        Logger.error("Failed to parse data: #{inspect(e)}")
        {:error, :parse_failed}
    end
  end

  defp parse_data(data), do: {:ok, data}

  defp parse_ruby_style_data(data) do
    cleaned = String.replace(data, "=>", ":")
    {parsed, _} = Code.eval_string(cleaned)
    {:ok, parsed}
  end

  defp get_inputs(inputs, context) when is_list(inputs) do
    Enum.map(inputs, fn input ->
      get_input(input, context)
    end)
  end

  defp get_inputs(_, _), do: []

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.trim() |> String.to_atom()
    Map.get(context, key) || Map.get(context, to_string(key))
  end

  defp get_input(input, _context) when is_binary(input) and input != "" do
    try do
      case Jason.decode(input) do
        {:ok, parsed} -> parsed
        {:error, _} -> eval_string_input(input)
      end
    rescue
      _ -> input
    end
  end

  defp get_input(input, _context), do: input

  defp eval_string_input(input) do
    {parsed, _} = Code.eval_string(input)
    parsed
  end
end
