defmodule SanbaseWeb.Graphql.ConCacheProvider do
  @moduledoc ~s"""
  Implements Sanbase.Cache.Behaviour for con_cache
  """
  @behaviour Sanbase.Cache.Behaviour

  @compile {:inline,
            get: 2,
            store: 3,
            get_or_store: 4,
            cache_item: 3,
            get_or_store_isolated: 5,
            execute_and_maybe_cache_function: 4}

  @max_cache_ttl 86_400

  @impl true
  def size(cache, :megabytes) do
    bytes_size = :ets.info(ConCache.ets(cache), :memory) * :erlang.system_info(:wordsize)

    (bytes_size / (1024 * 1024)) |> Float.round(2)
  end

  def count(cache) do
    cache
    |> ConCache.ets()
    |> :ets.tab2list()
    |> length
  end

  @impl true
  def clear_all(cache) do
    cache
    |> ConCache.ets()
    |> :ets.tab2list()
    |> Enum.each(fn {key, _} -> ConCache.delete(cache, key) end)
  end

  @impl true
  def get(cache, key) do
    case ConCache.get(cache, true_key(key)) do
      {:stored, value} -> value
      nil -> nil
    end
  end

  @impl true
  def store(cache, key, value) do
    case value do
      {:error, _} ->
        :ok

      {:nocache, _} ->
        Process.put(:has_nocache_field, true)
        :ok

      value ->
        cache_item(cache, key, {:stored, value})
    end
  end

  @impl true
  def get_or_store(cache, key, func, cache_modify_middleware) do
    # Do not include the TTL as part of the key name.
    true_key = true_key(key)

    case ConCache.get(cache, true_key) do
      {:stored, value} ->
        value

      _ ->
        get_or_store_isolated(cache, key, true_key, func, cache_modify_middleware)
    end
  end

  defp get_or_store_isolated(cache, key, true_key, func, middleware_func) do
    # This function is to be executed inside ConCache.isolated/3 call.
    # This isolated call locks the access for that key before doing anything else
    # Doing this ensures that the case where another process modified the key
    # before in the time between the previous check and the locking.
    fun = fn ->
      case ConCache.get(cache, true_key) do
        {:stored, value} ->
          value

        _ ->
          execute_and_maybe_cache_function(
            cache,
            key,
            func,
            middleware_func
          )
      end
    end

    ConCache.isolated(cache, true_key, fun)
  end

  defp execute_and_maybe_cache_function(cache, key, func, middleware_func) do
    # Execute the function and if it returns :ok tuple cache it
    # Errors are not cached. Also, caching can be manually disabled by
    # wrapping the result in a :nocache tuple
    case func.() do
      {:error, _} = error ->
        error

      {:middleware, _, _} = tuple ->
        # Decides on its behalf whether or not to put the value in the cache
        middleware_func.(cache, key, tuple)

      {:nocache, {:ok, _result} = value} ->
        Process.put(:do_not_cache_query, true)
        value

      value ->
        cache_item(cache, key, {:stored, value})
        value
    end
  end

  defp cache_item(cache, {key, ttl}, value) when is_integer(ttl) and ttl <= @max_cache_ttl do
    ConCache.put(cache, key, %ConCache.Item{
      value: value,
      ttl: :timer.seconds(ttl)
    })
  end

  defp cache_item(cache, key, value) do
    ConCache.put(cache, key, value)
  end

  defp true_key({key, ttl}) when is_integer(ttl) and ttl <= @max_cache_ttl, do: key
  defp true_key(key), do: key
end
