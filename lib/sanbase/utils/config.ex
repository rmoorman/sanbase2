defmodule Sanbase.Utils.Config do
  def module_get(module, key) do
    Application.fetch_env!(:sanbase, module)
    |> Keyword.get(key)
    |> parse_config_value()
  end

  def module_get!(module, key) do
    Application.fetch_env!(:sanbase, module)
    |> Keyword.fetch!(key)
    |> parse_config_value()
  end

  def module_get(module, key, default) do
    Application.fetch_env(:sanbase, module)
    |> case do
      {:ok, env} -> env |> Keyword.get(key, default)
      _ -> default
    end
    |> parse_config_value()
  end

  def module_get_integer!(module, key) do
    module_get!(module, key) |> Sanbase.Math.to_integer()
  end

  defp parse_config_value({:system, env_key, default}) do
    System.get_env(env_key) || default
  end

  defp parse_config_value({:system, env_key}) do
    System.get_env(env_key)
  end

  defp parse_config_value(value) do
    value
  end
end
