# Простой тестовый HTTP сервер для разработки
defmodule TestServer do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  # Health check
  get "/api/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok", timestamp: DateTime.utc_now()}))
  end

  # Получение деталей аккаунта
  get "/api/accounts/:id/detail" do
    send_resp(conn, 200, Jason.encode!(%{
      id: String.to_integer(id),
      email: "test@example.com",
      roles: ["admin", "user"],
      isActive: true,
      createdAt: "2024-01-01T00:00:00Z"
    }))
  end

  # Создание продукта
  post "/api/products" do
    {:ok, body, conn} = read_body(conn)
    data = Jason.decode!(body)

    response = %{
      id: :rand.uniform(1000),
      name: data["name"],
      description: data["description"],
      category: data["category"],
      basePrice: data["basePrice"],
      popularity: 0,
      createdAt: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    send_resp(conn, 201, Jason.encode!(response))
  end

  # Fallback
  match _ do
    send_resp(conn, 404, "Not found")
  end
end

# Запуск сервера
if System.get_env("MIX_ENV") != "test" do
  {:ok, _} = Plug.Cowboy.http(TestServer, [], port: 8082)
  IO.puts("Test server running on http://localhost:8082")
end
