defmodule FpLab4.Steps.ReportStep do
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

  defp calculate_stock(stock_info) do
    Enum.reduce(stock_info, 0, fn item, acc -> acc + item["countItems"] end)
  end
end
