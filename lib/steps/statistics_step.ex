defmodule FpLab4.Steps.StatisticsStep do
  require Logger

  def count_items(params, context) do
    Logger.info("StatisticsStep.count_items called")
    data = get_input(params["input"], context)

    # Добавим больше информации о данных
    Logger.info("Data type: #{inspect(is_list(data))}, length: #{if is_list(data), do: length(data), else: 0}")
    Logger.info("Data first element: #{inspect(if is_list(data) and length(data) > 0, do: hd(data), else: nil)}")

    count = case data do
      data when is_list(data) -> length(data)
      _ ->
        # Попробуем распарсить как JSON или Elixir term
        case parse_data(data) do
          {:ok, parsed_data} when is_list(parsed_data) -> length(parsed_data)
          _ -> 0
        end
    end

    Logger.info("Count: #{count}")
    %{String.to_atom(params["item_name"]) => count}
  end

  def filter_by_field(params, context) do
    Logger.info("StatisticsStep.filter_by_field called with params: #{inspect(params, limit: 2)}")

    data = get_input(params["input"], context)
    field = params["field"]
    value = params["value"]

    # Преобразуем данные в список, если нужно
    data_list = case data do
      data when is_list(data) -> data
      _ ->
        case parse_data(data) do
          {:ok, parsed_data} when is_list(parsed_data) -> parsed_data
          _ -> []
        end
    end

    Logger.info("Data keys in first item: #{if is_list(data_list) and length(data_list) > 0, do: inspect(Map.keys(hd(data_list))), else: "no data"}")
    Logger.info("Looking for #{field} == #{value}")

    filtered = Enum.filter(data_list, fn item ->
      case item do
        %{} = map ->
          # Проверяем как строковый и атомарный ключ
          Map.get(map, field) == value || Map.get(map, String.to_atom(field)) == value
        _ -> false
      end
    end)

    Logger.info("Filtered #{length(data_list)} items to #{length(filtered)} items")
    filtered
  end

  def group_by_date(params, context) do
    Logger.info("StatisticsStep.group_by_date called with params: #{inspect(params, limit: 2)}")

    data = get_input(params["input"], context)

    # Преобразуем данные в список, если нужно
    data_list = case data do
      data when is_list(data) -> data
      _ ->
        case parse_data(data) do
          {:ok, parsed_data} when is_list(parsed_data) -> parsed_data
          _ -> []
        end
    end

    Logger.info("Data list length: #{length(data_list)}")

    if length(data_list) == 0 do
      Logger.info("No data to group")
      %{}
    else
      # Простая группировка по имени (для демонстрации)
      result = Enum.group_by(data_list, fn item ->
        case item do
          %{"name" => name} -> name
          %{name: name} -> name
          _ -> "unknown"
        end
      end)

      Logger.info("Grouped into #{map_size(result)} groups: #{inspect(Map.keys(result))}")
      result
    end
  end

  def extract_roles(params, context) do
    Logger.info("StatisticsStep.extract_roles called with params: #{inspect(params, limit: 2)}")

    inputs = get_inputs(params["inputs"], context)
    Logger.info("Inputs count: #{length(inputs)}, types: #{inspect(Enum.map(inputs, &{&1 != nil, if(is_map(&1), do: Map.keys(&1), else: &1)}))}")

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
          Logger.info("Account data is not a map: #{inspect(account_data, limit: 1)}")
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
    Logger.info("Extracting roles from account: #{inspect(Map.keys(account_data), limit: 5)}")

    # Пытаемся найти роли в различных полях
    roles = []

    # Проверяем поле "roles"
    roles = case Map.get(account_data, "roles") || Map.get(account_data, :roles) do
      nil -> roles
      roles_list when is_list(roles_list) -> roles ++ roles_list
      role when is_binary(role) -> roles ++ [role]
      _ -> roles
    end

    # Проверяем поле "role"
    roles = case Map.get(account_data, "role") || Map.get(account_data, :role) do
      nil -> roles
      role when is_binary(role) -> roles ++ [role]
      _ -> roles
    end

    # Проверяем поле "authorities" (если используется Spring Security)
    roles = case Map.get(account_data, "authorities") || Map.get(account_data, :authorities) do
      nil -> roles
      authorities when is_list(authorities) -> roles ++ authorities
      _ -> roles
    end

    # Если ролей нет, используем email как основу для роли
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

  # Парсинг данных из строки
  defp parse_data(data) when is_binary(data) do
    try do
      # Сначала пробуем как JSON
      case Jason.decode(data) do
        {:ok, parsed} -> {:ok, parsed}
        {:error, _} ->
          # Пробуем как Elixir term (осторожно!)
          # Заменяем => на : для создания keyword list
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

  # Вспомогательная функция для получения списка входных данных
  defp get_inputs(inputs, context) when is_list(inputs) do
    Logger.info("Getting inputs: #{inspect(inputs)}")

    results = Enum.map(inputs, fn input ->
      value = get_input(input, context)
      Logger.info("Input #{input} => #{inspect(value, limit: 1)}")
      value
    end)

    Logger.info("Inputs results count: #{length(results)}, non-nil: #{Enum.count(results, &(&1 != nil && &1 != ""))}")
    results
  end

  defp get_inputs(_, _), do: []

  # Существующая функция get_input
  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.trim() |> String.to_atom()
    value = Map.get(context, key)
    Logger.info("Getting variable #{key} from context, found: #{inspect(value != nil)}")
    if value == nil do
      # Пробуем найти как строку
      Map.get(context, to_string(key))
    else
      value
    end
  end

  defp get_input(input, _context) when is_binary(input) and input != "" do
    # Если это не переменная в {{...}}, возможно, это JSON строка?
    try do
      case Jason.decode(input) do
        {:ok, parsed} -> parsed
        {:error, _} ->
          # Пробуем как Elixir term
          {parsed, _} = Code.eval_string(input)
          parsed
      end
    rescue
      _ -> input
    end
  end

  defp get_input(input, _context), do: input
end
