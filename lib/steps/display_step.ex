defmodule FpLab4.Steps.DisplayStep do
  @doc """
  Отображает дашборд с результатами
  """
  def show_dashboard(params, context) do
    report = get_input(params["report"], context)

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("📊 DASHBOARD: #{params["function"]}")
    IO.puts(String.duplicate("=", 80))

    case report do
      %{"total_posts" => total} ->
        IO.puts("📈 Total Posts: #{total}")
        IO.puts("📅 Latest Post: #{report["latest_post"]["title"]}")
        IO.puts("🏆 Top Posts:")
        Enum.each(report["top_posts"], fn post ->
          IO.puts("   • #{post["title"]} (❤️ #{post["likesCount"]})")
        end)

      %{"product_id" => product_id} ->
        IO.puts("🛍️ Product Report")
        IO.puts("   ID: #{product_id}")
        IO.puts("   Name: #{report["name"]}")
        IO.puts("   Stock Total: #{report["stock_total"]}")

      _ ->
        IO.puts("📋 Report:")
        IO.inspect(report, limit: :infinity, printable_limit: :infinity)
    end

    IO.puts(String.duplicate("=", 80) <> "\n")

    context
  end

  def print_summary(params, context) do
    report = get_input(params["report"], context)

    IO.puts("\n" <> String.duplicate("-", 60))
    IO.puts("📋 SUMMARY REPORT")
    IO.puts(String.duplicate("-", 60))

    case report do
      %{"total_users" => total, "active_users_count" => active} ->
        IO.puts("👥 Users: #{total} total, #{active} active")
        IO.puts("📅 Registration Stats:")
        if is_map(report["registration_stats"]) do
          Enum.each(report["registration_stats"], fn {month, count} ->
            IO.puts("   #{month}: #{length(count)} users")
          end)
        end

      _ ->
        IO.inspect(report, limit: :infinity)
    end

    IO.puts(String.duplicate("-", 60))

    context
  end

  defp get_input("{{" <> rest, context) do
    key = String.trim_trailing(rest, "}}") |> String.to_atom()
    Map.get(context, key)
  end
  defp get_input(value, _context), do: value
end
