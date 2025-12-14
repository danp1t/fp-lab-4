defmodule Workflows.Config do
  @configs %{
    "api_config.yaml" => %{
      base_url: "http://localhost:8080",
      auth_token: "eyJhbGciOiJIUzUxMiJ9...",
      account_id: 2,
      admin_token: "eyJhbGciOiJIUzUxMiJ9..."
    },
    "test_data.yaml" => %{
      test_product: %{
        name: "Test Product",
        description: "Test product description",
        category: "TestCategory",
        base_price: 1000
      }
    }
  }

  def get_config(name), do: @configs[name]
  def merge_configs(names), do: Enum.reduce(names, %{}, &Map.merge(&2, get_config(&1)))
end
