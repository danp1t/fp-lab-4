defmodule Workflows.ConfigManager do
  @configs_path "workflows/configs/"

  def load_configs(include_configs, base_context \\ %{}) do
    Enum.reduce(include_configs, base_context, fn config_name, acc ->
      config = load_config_file(config_name)
      Map.merge(acc, config)
    end)
  end

  defp load_config_file(config_name) do
    # Для тестирования используем хардкод конфиги
    case config_name do
      "workflows/configs/api_config.yaml" ->
        %{
          base_url: "http://localhost:8080",
          auth_token: "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJleGFtcGxlMzNAZXhhbXBsZS5jb20iLCJpYXQiOjE3NjQ1Mjc0MTgsImV4cCI6MTc2NDYxMzgxOH0.D2NLz8PhD3lMwjid8BlpPKIz8TSiHhIg1ZLUjTMLbuO0nMpGbgoblSnuFXgHr_rmc7VH88j3Wv64fIhiW2Pdtg",
          account_id: 2,
          admin_token: "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJleGFtcGxlMkBleGFtcGxlLmNvbSIsImlhdCI6MTc2MzkxMTg4NCwiZXhwIjoxNzYzOTk4Mjg0fQ.Z6GHMG7H2h0Zd0ktS4iefJS_dZ5uK2ANJGzX9mUIiTalkK7xJOJfaCgaOsmwdl-Aof1rFQSPY3TxltBpz2KPug"
        }
      "workflows/configs/test_data.yaml" ->
        %{
          test_product: %{
            name: "Test Product",
            description: "Test product description",
            category: "TestCategory",
            base_price: 1000
          },
          test_post: %{
            title: "Test Post",
            text: "Test post content",
            owner_id: 2
          }
        }
      _ ->
        IO.puts("Warning: Config file #{config_name} not found, using empty config")
        %{}
    end
  end

  def merge_contexts(base_context, new_context) do
    Map.merge(base_context, new_context, fn _key, v1, v2 ->
      cond do
        is_map(v1) and is_map(v2) -> Map.merge(v1, v2)
        is_list(v1) and is_list(v2) -> v1 ++ v2
        true -> v2
      end
    end)
  end
end
