defmodule Workflows.Step do
  @moduledoc """
  Определения типов шагов workflow.
  Содержит структуры для Task, Parallel и Sequential шагов.
  """

  defmodule Task do
    @moduledoc "Структура для представления задачи workflow"
    @enforce_keys [:id, :module]
    defstruct [
      :id,
      :name,
      :type,
      :module,
      :function,
      :method,
      :url,
      :headers,
      :body,
      :parameters,
      :on_success,
      :on_error
    ]
  end

  defmodule Parallel do
    @moduledoc "Структура для представления параллельных шагов"
    @enforce_keys [:id, :steps]
    defstruct [
      :id,
      :name,
      :type,
      :steps,
      :on_success
    ]
  end

  defmodule Sequential do
    @moduledoc "Структура для представления последовательных шагов"
    @enforce_keys [:id, :steps]
    defstruct [
      :id,
      :name,
      :type,
      :steps,
      :on_success
    ]
  end
end
