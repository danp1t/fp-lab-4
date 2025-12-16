# fp-lab-4
## Лабораторная работа №4. Путинцев Данил. Система оркестрации параллельных процессов

### Описание
В Yaml-файле описывается сценарий, который состоит из шагов. Данные шаги могут исполнять как последовательно так и параллельно

Цель - создать систему оркестрации, которая позволит описывать исполнение E2E, где явно будет прописываться, что выполняется параллельно, а что последовательно. 

### Архитектура

#### Parser
Задачи парсера:
1. Валидация и преобразование YAML-описаний workflow во внутренние структуры
2. Поддержка трех типов шагов: Task, Parallel, Sequential
3. Извлечение переменных и построение графа зависимостей

#### Workflow Executor
1. Управление выполнением workflow на уровне шагов
2. Обработка ошибок и механизм повторных попыток (retry)
3. Управление контекстом выполнения и передачей данных между шагами

#### Registry
1. Централизованный реестр всех запущенных workflow
2. Связь между именами workflow и их PID
3. Мониторинг жизненного цикла процессов

#### Main Supervisor
1. Иерархическая структура супервизоров для отказоустойчивости
2. Динамический запуск и остановка workflow
3. Стратегии восстановления процессов

#### Workflow Supervisor
1. Контролирует выполнение конкретного E2E
2. Раздает задачи worker'ам для выполнения конкретных шагов
3. Оповещает Main Supervisor в случае ошибки
4. Хранит статусы каждого шага, результаты выполнения шагов и общий контекст выполнения

#### Worker
1. Исполняет конкретный шаг

#### Steps - реализация конкретных шагов
1. HttpStep: Выполнение HTTP-запросов (GET, POST, PUT, DELETE)
2. StatisticsStep: Статистическая обработка данных
3. ExportStep: Экспорт результатов в файлы
4. DisplayStep: Форматированный вывод в консоль
5. ReportStep: Генерация отчетов



### Пример описания E2E в формате Yaml
```yaml
name: "Статистика по ролям пользователей"
include_configs:
  - "workflows/configs/api_config.yaml"

steps:
  - id: "load_all_accounts"
    type: "task"
    name: "Загрузка всех аккаунтов"
    config:
      module: "FpLab4.Steps.HttpStep"
      method: "GET"
      url: "{{base_url}}/api/accounts"
      headers:
        Authorization: "Bearer {{admin_token}}"
        Content-Type: "application/json"
    on_success:
      save_response: "all_accounts"

  - id: "analyze_accounts"
    type: "parallel"
    name: "Анализ аккаунтов"
    steps:
      - id: "count_total_users"
        type: "task"
        name: "Количество пользователей"
        config:
          module: "FpLab4.Steps.StatisticsStep"
          function: "count_items"
          input: "{{all_accounts}}"
          item_name: "users"
        on_success:
          save_result: "total_users"

      - id: "get_admin_users"
        type: "task"
        name: "Получение администраторов"
        config:
          module: "FpLab4.Steps.StatisticsStep"
          function: "filter_by_field"
          input: "{{all_accounts}}"
          field: "email"
          value: "admin"
        on_success:
          save_result: "admin_users"

      - id: "group_by_email_domain"
        type: "task"
        name: "Группировка по домену email"
        config:
          module: "FpLab4.Steps.StatisticsStep"
          function: "group_by_date"
          input: "{{all_accounts}}"
          date_field: "email"
          interval: "domain"
        on_success:
          save_result: "email_groups"

  - id: "get_accounts_with_roles"
    type: "parallel"
    name: "Получение аккаунтов с ролями"
    steps:
      - id: "get_account_details_1"
        type: "task"
        name: "Детали аккаунта 1"
        config:
          module: "FpLab4.Steps.HttpStep"
          method: "GET"
          url: "{{base_url}}/api/accounts/{{all_accounts[0].id}}/detail"
          headers:
            Authorization: "Bearer {{admin_token}}"
            Content-Type: "application/json"
        on_success:
          save_response: "account_details_1"

      - id: "get_account_details_2"
        type: "task"
        name: "Детали аккаунта 2"
        config:
          module: "FpLab4.Steps.HttpStep"
          method: "GET"
          url: "{{base_url}}/api/accounts/{{all_accounts[1].id}}/detail"
          headers:
            Authorization: "Bearer {{admin_token}}"
            Content-Type: "application/json"
        on_success:
          save_response: "account_details_2"

      - id: "get_account_details_3"
        type: "task"
        name: "Детали аккаунта 3"
        config:
          module: "FpLab4.Steps.HttpStep"
          method: "GET"
          url: "{{base_url}}/api/accounts/{{all_accounts[2].id}}/detail"
          headers:
            Authorization: "Bearer {{admin_token}}"
            Content-Type: "application/json"
        on_success:
          save_response: "account_details_3"

  - id: "analyze_role_distribution"
    type: "task"
    name: "Анализ распределения ролей"
    config:
      module: "FpLab4.Steps.StatisticsStep"
      function: "extract_roles"
      inputs:
        - "{{account_details_1}}"
        - "{{account_details_2}}"
        - "{{account_details_3}}"
    on_success:
      save_result: "role_samples"

  - id: "generate_role_report"
    type: "task"
    name: "Генерация отчета по ролям"
    config:
      module: "FpLab4.Steps.ReportStep"
      function: "generate_role_report"
      inputs:
        total_users: "{{total_users}}"
        admin_users_count: "{{admin_users|length}}"
        email_groups: "{{email_groups}}"
        role_samples: "{{role_samples}}"
    on_success:
      save_result: "role_report"

  - id: "export_statistics"
    type: "parallel"
    name: "Экспорт статистики"
    steps:
      - id: "save_to_json"
        type: "task"
        name: "Сохранение в JSON"
        config:
          module: "FpLab4.Steps.ExportStep"
          function: "save_json"
          data: "{{role_report}}"
          filename: "role_statistics_#{timestamp}.json"

      - id: "print_summary"
        type: "task"
        name: "Вывод сводки"
        config:
          module: "FpLab4.Steps.DisplayStep"
          function: "print_summary"
          report: "{{role_report}}"
```

### Запуск
```bash
mix run cli.exs
```

Основные команды:
```bash
  help                 - Показать эту справку
  list                 - Показать список запущенных workflows
  status <name>        - Показать статус workflow
  run <name> <file>    - Запустить workflow
  clear                - Очистить экран
  exit/quit            - Выйти из интерактивного режима

Примеры:
  run test workflows/test_workflow.yml
  list
  status test
  stop test

```

Пример запуска Workflow
```
run test workflows/test_workflow.yml
```

