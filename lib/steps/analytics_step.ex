defmodule FpLab4.Steps.AnalyticsStep do
  alias Workflows.Interpolator

  def analyze_post_engagement(params, context) do
    post_data = get_input(params["inputs"]["post_data"], context)
    feed_data = get_input(params["inputs"]["feed_data"], context)
    interactions = get_input(params["inputs"]["interactions"], context)

    engagement_score = calculate_engagement_score(post_data, interactions)
    ranking = calculate_feed_ranking(post_data, feed_data)
    recommendations = generate_recommendations(engagement_score, ranking)

    analytics = %{
      engagement_score: engagement_score,
      feed_ranking: ranking,
      recommendations: recommendations,
      metrics: %{
        likes_count: get_likes_count(interactions),
        comments_count: get_comments_count(interactions),
        has_attachment: has_attachment?(interactions)
      },
      analyzed_at: DateTime.utc_now()
    }

    update_context(context, analytics, params["on_success"])
  end

  defp calculate_engagement_score(post_data, interactions) do
    base_score = 1.0

    # Учитываем лайки
    likes_score = (get_likes_count(interactions) / 10) |> min(2.0)

    # Учитываем комментарии
    comments_score = (get_comments_count(interactions) / 5) |> min(2.0)

    # Учитываем наличие вложений
    attachment_score = if has_attachment?(interactions), do: 1.5, else: 1.0

    (base_score * likes_score * comments_score * attachment_score)
    |> Float.round(2)
  end

  defp calculate_feed_ranking(post_data, feed_data) do
    post_id = post_data["id"]

    case Enum.find_index(feed_data, fn item -> item["id"] == post_id end) do
      nil -> :not_found
      index -> index + 1
    end
  end

  defp generate_recommendations(engagement_score, ranking) do
    recommendations = []

    recommendations = if engagement_score < 2.0 do
      ["Consider adding more engaging content", "Try posting at peak hours"] ++ recommendations
    else
      recommendations
    end

    recommendations = if ranking > 10 do
      ["Consider boosting post visibility"] ++ recommendations
    else
      recommendations
    end

    recommendations
  end

  defp get_likes_count(interactions) do
    interactions["likes"] |> List.wrap() |> length()
  end

  defp get_comments_count(interactions) do
    interactions["comments"] |> List.wrap() |> length()
  end

  defp has_attachment?(interactions) do
    interactions["attachments"] |> List.wrap() |> length() > 0
  end

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.to_atom()
    Map.get(context, key)
  end

  defp get_input(input, _context) when is_map(input) or is_list(input), do: input
  defp get_input(input, context), do: Interpolator.interpolate(input, context)

  defp update_context(context, result, on_success) do
    case on_success["save_result"] do
      nil -> Map.put(context, :analytics_result, result)
      key -> Map.put(context, String.to_atom(key), result)
    end
  end
end
