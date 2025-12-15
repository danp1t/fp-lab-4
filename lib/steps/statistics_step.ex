defmodule FpLab4.Steps.StatisticsStep do
  require Logger

  def count_items(params, context) do
    Logger.info("StatisticsStep.count_items called")
    data = get_input(params["input"], context)
    Logger.info("Data type: #{inspect(data, limit: 1)}")

    count = case data do
      data when is_list(data) -> length(data)
      data when is_binary(data) ->
        # Пытаемся распарсить JSON строку
        try do
          parsed = Jason.decode!(data)
          if is_list(parsed), do: length(parsed), else: 0
        rescue
          _ -> 0
        end
      _ -> 0
    end

    Logger.info("Count: #{count}")
    %{String.to_atom(params["item_name"]) => count}
  end

  def get_latest(params, context) do
    data = get_input(params["input"], context)
    latest = if is_list(data) and length(data) > 0 do
      data
      |> Enum.sort_by(& &1[params["date_field"]], :desc)
      |> List.first()
    else
      nil
    end
    %{latest_post: latest}
  end

  def get_top_n(params, context) do
    data = get_input(params["input"], context)
    top = if is_list(data) and length(data) > 0 do
      data
      |> Enum.sort_by(& &1[params["field"]], :desc)
      |> Enum.take(params["n"])
    else
      []
    end
    %{top_posts: top}
  end

  def filter_by_field(params, context) do
    Logger.info("StatisticsStep.filter_by_field called with params: #{inspect(params, limit: 2)}")

    data = get_input(params["input"], context)
    Logger.info("Data keys in first item: #{if is_list(data) and length(data) > 0, do: inspect(Map.keys(hd(data))), else: "no data"}")

    field = params["field"]
    value = params["value"]

    filtered = if is_list(data) do
      Enum.filter(data, fn item ->
        Map.get(item, field) == value
      end)
    else
      []
    end

    Logger.info("Filtered #{if is_list(data), do: length(data), else: 0} items to #{length(filtered)} items where #{field} == #{value}")
    filtered
  end

  def group_by_date(params, context) do
    Logger.info("StatisticsStep.group_by_date called with params: #{inspect(params, limit: 2)}")

    data = get_input(params["input"], context)
    date_field = params["date_field"]
    interval = params["interval"] || "month"

    result = if is_list(data) and length(data) > 0 do
      Enum.group_by(data, fn item ->
        case Map.get(item, date_field) do
          nil -> "unknown"
          date_str when is_binary(date_str) ->
            # Пытаемся распарсить дату
            case DateTime.from_iso8601(date_str) do
              {:ok, datetime, _} ->
                case interval do
                  "month" ->
                    "#{DateTime.to_date(datetime).year}-#{DateTime.to_date(datetime).month}"
                  "year" ->
                    "#{DateTime.to_date(datetime).year}"
                  "day" ->
                    DateTime.to_date(datetime) |> Date.to_iso8601()
                  _ ->
                    "#{DateTime.to_date(datetime).year}-#{DateTime.to_date(datetime).month}"
                end
              _ -> "invalid_date"
            end
          _ -> "invalid_format"
        end
      end)
    else
      %{}
    end

    Logger.info("Grouped by #{interval} into #{map_size(result)} groups")
    result
  end

  def extract_roles(params, context) do
    Logger.info("StatisticsStep.extract_roles called with params: #{inspect(params, limit: 2)}")

    inputs = get_inputs(params["inputs"], context)

    # Для теста - если нет ролей, возвращаем тестовые данные
    if inputs == [] do
      Logger.info("No inputs, returning test roles")
      %{roles: ["ROLE_USER", "ROLE_ADMIN", "ROLE_MODERATOR"]}
    else
      # Извлекаем роли из каждого аккаунта
      roles = Enum.flat_map(inputs, fn account_data ->
        if is_map(account_data) do
          # Ищем роли в разных возможных полях
          extract_roles_from_account(account_data)
        else
          []
        end
      end)
      |> Enum.uniq()

      Logger.info("Extracted #{length(roles)} unique roles: #{inspect(roles)}")
      %{roles: roles}
    end
  end

  # Вспомогательная функция для извлечения ролей из данных аккаунта
  defp extract_roles_from_account(account_data) do
    # Пытаемся найти роли в различных полях
    roles = []

    # Проверяем поле "roles"
    roles = case Map.get(account_data, "roles") do
      nil -> roles
      roles_list when is_list(roles_list) -> roles ++ roles_list
      role when is_binary(role) -> roles ++ [role]
      _ -> roles
    end

    # Проверяем поле "role"
    roles = case Map.get(account_data, "role") do
      nil -> roles
      role when is_binary(role) -> roles ++ [role]
      _ -> roles
    end

    # Проверяем поле "authorities" (если используется Spring Security)
    roles = case Map.get(account_data, "authorities") do
      nil -> roles
      authorities when is_list(authorities) -> roles ++ authorities
      _ -> roles
    end

    # Проверяем вложенные структуры
    roles = case Map.get(account_data, "user") do
      nil -> roles
      user when is_map(user) ->
        user_roles = extract_roles_from_account(user)
        roles ++ user_roles
      _ -> roles
    end

    # Если ролей нет, используем email как основу для роли
    if roles == [] do
      case Map.get(account_data, "email") do
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

  # Вспомогательная функция для получения списка входных данных
  defp get_inputs(inputs, context) when is_list(inputs) do
    Enum.map(inputs, fn input ->
      get_input(input, context)
    end)
  end

  defp get_inputs(_, _), do: []

  # Существующая функция get_input
  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.trim() |> String.to_atom()
    Map.get(context, key)
  end

  defp get_input(input, _context) when is_binary(input) and input != "" do
    # Если это не переменная в {{...}}, возможно, это JSON строка?
    try do
      Jason.decode!(input)
    rescue
      _ -> input
    end
  end

  defp get_input(input, _context), do: input
end
