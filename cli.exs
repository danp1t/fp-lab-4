# bin/run_workflow.exs (в корне проекта)
#!/usr/bin/env elixir

# Скрипт для запуска одной команды без интерактивного режима
# Использование: mix run bin/run_workflow.exs --list

if length(System.argv()) == 0 do
  # Если аргументов нет, запускаем интерактивный режим
  Workflows.CLI.main([])
else
  # Если есть аргументы, используем неинтерактивный режим
  Workflows.CLI.run_non_interactive(System.argv())
end
