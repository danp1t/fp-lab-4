defmodule FpLab4.Steps.ReportStep do
  require Logger

  def generate_product_report(params, context) do
    %{
      product_id: context.product_id,
      name: context.product_details["name"],
      variants: [
        context.variant_small,
        context.variant_medium,
        context.variant_large
      ],
      available: context.availability_info["available"],
      stock_total: calculate_stock(context.stock_info),
      generated_at: DateTime.utc_now()
    }
  end

  def generate_post_report(params, context) do
    %{
      total_posts: context.posts_count,
      latest_post: context.latest_post,
      top_posts: context.top_posts,
      sample_posts: [
        context.post_details_1,
        context.post_details_2,
        context.post_details_3
      ]
    }
  end

  def generate_role_report(params, context) do
    Logger.info("ReportStep.generate_role_report called")

    total_users = get_input(params["total_users"], context)
    example_users = get_input(params["example_users"], context)
    name_groups = get_input(params["name_groups"], context)
    role_samples = get_input(params["role_samples"], context)

    Logger.info("total_users: #{inspect(total_users, limit: 2)}")

    # Извлекаем числовые значения
    total_users_count = extract_count(total_users)
    example_users_count = if is_list(example_users), do: length(example_users), else: 0

    %{
      total_users: total_users_count,
      example_users_count: example_users_count,
      name_groups: name_groups,
      role_samples: extract_roles(role_samples),
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

  defp calculate_stock(stock_info) do
    Enum.reduce(stock_info, 0, fn item, acc -> acc + item["countItems"] end)
  end

  # Вспомогательная функция для получения значения из контекста
  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.trim() |> String.to_atom()
    Map.get(context, key)
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
