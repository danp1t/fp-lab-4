defmodule Workflows.Step do
  defmodule Task do
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
