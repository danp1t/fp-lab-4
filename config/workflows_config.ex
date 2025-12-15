defmodule Workflows.Config do
  @configs %{
    "api_config.yaml" => %{
      base_url: "http://localhost:8080",
      auth_token: "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkB0ZXN0LmNvbSIsImlhdCI6MTc2NTgyMTc3MiwiZXhwIjoxNzY1OTA4MTcyfQ.-R2mfaT5j-b2dHn2WKXFpAjnECct0J_6_5I47X3uoOFyOLUsky57NCBLjsw6Boq5izLgHuKd_L7RImRp3M1pCQ",
      account_id: 4,
      admin_token: "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkB0ZXN0LmNvbSIsImlhdCI6MTc2NTgyMTc3MiwiZXhwIjoxNzY1OTA4MTcyfQ.-R2mfaT5j-b2dHn2WKXFpAjnECct0J_6_5I47X3uoOFyOLUsky57NCBLjsw6Boq5izLgHuKd_L7RImRp3M1pCQ"
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
