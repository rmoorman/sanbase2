defmodule Sanbase.ExternalServices.RateLimiting.Server do
  alias Sanbase.Utils.Config
  @module Config.module_get(__MODULE__, :implementation_module)

  defdelegate child_spec(name, options), to: @module
  defdelegate wait(name), to: @module
  defdelegate wait_until(name, until), to: @module
end
