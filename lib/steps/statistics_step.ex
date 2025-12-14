defmodule FpLab4.Steps.StatisticsStep do
  def count_items(params, context) do
    data = get_input(params["input"], context)
    count = if is_list(data), do: length(data), else: 0
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

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.to_atom()
    Map.get(context, key)
  end
  defp get_input(input, _context), do: input
end
