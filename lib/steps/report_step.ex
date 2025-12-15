defmodule FpLab4.Steps.ReportStep do
  require Logger

  def generate_role_report(params, context) do
    Logger.info("ReportStep.generate_role_report called")

    # Используем реальные значения из контекста
    total_users = Map.get(context, :total_users) || %{users: 0}
    admin_users = Map.get(context, :admin_users) || []
    email_groups = Map.get(context, :email_groups) || %{}
    role_samples = Map.get(context, :role_samples) || %{roles: []}

    Logger.info("total_users from context: #{inspect(total_users)}")
    Logger.info("admin_users length: #{length(admin_users)}")
    Logger.info("email_groups keys: #{inspect(Map.keys(email_groups))}")
    Logger.info("role_samples: #{inspect(role_samples)}")

    %{
      total_users: total_users[:users] || 0,
      admin_users_count: length(admin_users),
      email_groups: email_groups,
      role_samples: role_samples[:roles] || [],
      generated_at: DateTime.utc_now(),
      report_type: "role_statistics"
    }
  end

  defp extract_count(data) do
    case data do
      %{"users" => count} -> count
      %{users: count} -> count
      count when is_integer(count) -> count
      _ -> 0
    end
  end

  defp extract_roles(data) do
    case data do
      %{"roles" => roles} -> roles
      %{roles: roles} -> roles
      roles when is_list(roles) -> roles
      _ -> []
    end
  end

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.trim() |> String.to_atom()
    value = Map.get(context, key)
    Logger.info("ReportStep: Getting variable #{key}, found: #{inspect(value != nil)}, type: #{inspect(value, limit: 1)}")
    if value == nil do
      # Пробуем найти как строку
      Map.get(context, to_string(key))
    else
      value
    end
  end

  defp get_input(value, _context) when is_binary(value) and value != "" do
    # Если это не переменная, может быть JSON строка?
    try do
      Jason.decode!(value)
    rescue
      _ -> value
    end
  end

  defp get_input(value, _context), do: value
end
