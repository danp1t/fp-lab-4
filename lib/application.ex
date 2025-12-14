defmodule FpLab4.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Кастомный реестр для управления процессами
      Workflows.Registry,

      # Главный супервизор workflow
      Workflows.MainSupervisor,

      # Монитор для наблюдения
      Workflows.Monitor,

      # Динамический супервизор для HTTP клиентов
      {DynamicSupervisor, strategy: :one_for_one, name: Workflows.DynamicSupervisor}
    ]

    opts = [strategy: :one_for_one, name: FpLab4.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
