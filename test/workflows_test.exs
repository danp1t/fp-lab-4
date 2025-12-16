defmodule WorkflowsTest do
  use ExUnit.Case

  alias Workflows.Parser
  alias Workflows.Interpolator

  describe "Parser" do
    test "Парсинг Yaml" do
      yaml_content = """
      name: "Test Workflow"
      include_configs: ["workflows/configs/api_config.yaml"]
      steps:
        - id: "step1"
          type: "task"
          name: "HTTP Request"
          config:
            module: "FpLab4.Steps.HttpStep"
            function: "execute"
            method: "GET"
            url: "{{base_url}}/api/test"
            headers:
              Authorization: "Bearer {{auth_token}}"
          on_success:
            save_response: "http_result"
      """

      assert {:ok, workflow} = Parser.parse_workflow(yaml_content)
      assert workflow.name == "Test Workflow"
      assert workflow.include_configs == ["workflows/configs/api_config.yaml"]
      assert length(workflow.steps) == 1

      step = hd(workflow.steps)
      assert step.id == "step1"
      assert step.type == "task"
      assert step.module == "FpLab4.Steps.HttpStep"
      assert step.on_success == %{save_response: "http_result"}
    end
  end

  describe "Interpolator" do
    test "Подстановка переменных из Yaml" do
      context = %{name: "John", age: 30}

      assert Interpolator.interpolate("Hello {{name}}", context) == "Hello John"
      assert Interpolator.interpolate("Age: {{age}}", context) == "Age: 30"
    end

    test "Обрабатываем вложенные структуры" do
      template = %{
        "user" => "{{name}}",
        "details" => %{"age" => "{{age}}"}
      }

      context = %{name: "Alice", age: 25}

      result = Interpolator.interpolate(template, context)
      assert result["user"] == "Alice"
      assert result["details"]["age"] == "25"
    end

    test "Обрабатываем списки" do
      template = ["{{item1}}", "{{item2}}", "static"]
      context = %{item1: "first", item2: "second"}

      result = Interpolator.interpolate(template, context)
      assert result == ["first", "second", "static"]
    end

    test "Возвращаем пустую строку для отсутствующей переменной" do
      assert Interpolator.interpolate("{{missing}}", %{}) == ""
    end
  end

  describe "StatisticsStep" do
    alias FpLab4.Steps.StatisticsStep

    test "Количество элементов в списке" do
      params = %{"input" => "{{data}}", "item_name" => "users_count"}
      context = %{data: [%{}, %{}, %{}]}

      result = StatisticsStep.count_items(params, context)
      assert result == %{users_count: 3}
    end

    test "Возвращаем самый последний элемент по дате" do
      items = [
        %{"id" => 1, "date" => "2024-01-01T00:00:00Z"},
        %{"id" => 2, "date" => "2024-01-03T00:00:00Z"},
        %{"id" => 3, "date" => "2024-01-02T00:00:00Z"}
      ]

      params = %{"input" => "{{items}}", "date_field" => "date"}
      context = %{items: items}

      result = StatisticsStep.get_latest(params, context)
      assert result["id"] == 2
    end

    test "Возвращаем топ-N элементов по полю" do
      items = [
        %{"id" => 1, "score" => 10},
        %{"id" => 2, "score" => 30},
        %{"id" => 3, "score" => 20},
        %{"id" => 4, "score" => 5}
      ]

      params = %{"input" => "{{items}}", "field" => "score", "n" => 2}
      context = %{items: items}

      result = StatisticsStep.get_top_n(params, context)
      assert length(result) == 2
      assert hd(result)["id"] == 2
      assert List.last(result)["id"] == 3
    end

    test "Извлекает роли из данных аккаунтов" do
      params = %{"inputs" => ["{{account1}}", "{{account2}}"]}

      context = %{
        account1: %{"roles" => ["ROLE_USER", "ROLE_ADMIN"]},
        account2: %{"role" => "ROLE_MODERATOR"}
      }

      result = StatisticsStep.extract_roles(params, context)
      assert result[:roles] |> Enum.sort() == ["ROLE_ADMIN", "ROLE_MODERATOR", "ROLE_USER"]
    end
  end

  describe "ConfigManager" do
    alias Workflows.ConfigManager

    test "Загружаем API конфигурацию" do
      configs = ConfigManager.load_configs(["workflows/configs/api_config.yaml"])

      assert configs[:base_url] == "http://localhost:8080"
      assert is_binary(configs[:auth_token])
      assert configs[:account_id] == 4
    end

    test "Объединяет контексты" do
      base = %{a: 1, nested: %{x: 1}}
      new = %{b: 2, nested: %{y: 2}}

      result = ConfigManager.merge_contexts(base, new)
      assert result.a == 1
      assert result.b == 2
      assert result.nested == %{x: 1, y: 2}
    end
  end
end
