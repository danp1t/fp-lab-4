# fp-lab-4
## Лабораторная работа №4. Путинцев Данил. Система оркестрации параллельных процессов

### Описание
В Yaml-файле описывается сценарий, который состоит из шагов. Данные шаги могут исполнять как последовательно так и параллельно
Цель - создать систему оркестрации, которая позволит описывать исполнение E2E, где явно будет прописываться, что выполняется параллельно, а что последовательно. 

### Архитектура

#### Parser
Задачи парсера:
1. Валидация Workflow
2. Преобразует аргументы в структуры Elixir
3. Строит граф зависимости шагов

#### Main Supervisor
1. Монитор для контроля выполнения E2E. 
2. Запуск E2E
3. Создает и запускает Workflow Supervisor

#### Workflow Supervisor
1. Контролирует выполнение конкретного E2E
2. Раздает задачи worker'ам для выполнения конкретных шагов
3. Оповещает Main Supervisor в случае ошибки
4. Хранит статусы каждого шага, результаты выполнения шагов и общий контекст выполнения

#### Worker
1. Исполняет конкретный шаг

#### Steps - реализация конкретных шагов
1. Описывает порядок действий, которые необходимо выполнить, например отправка REST запроса, парсинг его ответа.



### Пример описания E2E в формате Yaml
```ya
name: "Add Product"
parameters:
  product_id: 123
  user_id: 456

steps:
  check_permission:
    module: "FpLab4.Steps.CheckPermission"
    function: "run"
  
  get_info_product:
    parallel:
      get_products:
        module: "FpLab4.Steps.GetProducts"
        function: "run"
      
      get_info_products:
        module: "FpLab4.Steps.GetInfoProducts"
        function: "run"
  
  add_product:
    sequential:
      add_info_product:
        module: "FpLab4.Steps.AddInfoProduct"
        function: "run"
      
      add_product:
        module: "FpLab4.Steps.AddProduct"
        function: "run"
```

