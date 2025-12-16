defmodule Workflows.ConfigManager do
  def load_configs(include_configs, base_context \\ %{}) do
    Enum.reduce(include_configs, base_context, fn config_name, acc ->
      config = load_config_file(config_name)
      Map.merge(acc, config)
    end)
  end

  defp load_config_file(config_name) do
    case config_name do
      "workflows/configs/api_config.yaml" ->
        %{
          base_url: "http://localhost:8080",
          auth_token:
            "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkB0ZXN0LmNvbSIsImlhdCI6MTc2NTgyMjI5MywiZXhwIjoxNzY1OTA4NjkzfQ.aizQNmjNZz5qoEkSBd_Ksi8_wXVC0eq76xIGY1sEOvFImPVBRvpzfPmTQyu3nm08QBGcpHEaRnkxgCK4zubOyQ",
          account_id: 4,
          admin_token:
            "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkB0ZXN0LmNvbSIsImlhdCI6MTc2NTgyMjI5MywiZXhwIjoxNzY1OTA4NjkzfQ.aizQNmjNZz5qoEkSBd_Ksi8_wXVC0eq76xIGY1sEOvFImPVBRvpzfPmTQyu3nm08QBGcpHEaRnkxgCK4zubOyQ"
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
        IO.puts("Ошибка: Конфигурационный файл #{config_name} не найден")
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
