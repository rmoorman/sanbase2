defmodule SanbaseWeb.Graphql.Resolvers.PriceResolver do
  require Logger

  import Absinthe.Resolution.Helpers
  import Ecto.Query

  alias SanbaseWeb.Graphql.PriceStore
  alias Sanbase.Model.Project

  @total_market "TOTAL_MARKET"
  @total_market_measurement "TOTAL_MARKET_total-market"

  @doc """
    Returns a list of price points for the given ticker. Optimizes the number of queries
    to the DB by inspecting the requested fields.
  """
  @deprecated "Use history price by slug instead of ticker"
  def history_price(_root, %{ticker: @total_market} = args, %{context: %{loader: loader}}) do
    loader
    |> Dataloader.load(PriceStore, @total_market_measurement, args)
    |> on_load(&total_market_history_price_on_load(&1, args))
  end

  @doc """
    Returns a list of price points for the given ticker. Optimizes the number of queries
    to the DB by inspecting the requested fields.
  """
  def history_price(_root, %{slug: @total_market} = args, %{context: %{loader: loader}}) do
    loader
    |> Dataloader.load(PriceStore, @total_market_measurement, args)
    |> on_load(&total_market_history_price_on_load(&1, args))
  end

  def ohlcv(_root, %{slug: @total_market} = args, %{context: %{loader: loader}}) do
    loader
    |> Dataloader.load(PriceStore, @total_market_measurement, args)
    |> on_load(&total_market_history_price_on_load(&1, args))
  end

  @deprecated "Use history price by slug"
  def history_price(_root, %{ticker: ticker} = args, %{context: %{loader: loader}}) do
    with slug when not is_nil(slug) <- slug_by_ticker(ticker) do
      ticker_cmc_id = ticker <> "_" <> slug

      loader
      |> Dataloader.load(PriceStore, ticker_cmc_id, args)
      |> on_load(&history_price_on_load(&1, ticker_cmc_id, args))
    else
      error ->
        {:error, "Cannot fetch history price for #{ticker}. Reason: #{inspect(error)}"}
    end
  end

  def history_price(_root, %{slug: slug} = args, %{context: %{loader: loader}}) do
    with ticker when not is_nil(ticker) <- Project.ticker_by_slug(slug) do
      ticker_cmc_id = ticker <> "_" <> slug

      loader
      |> Dataloader.load(PriceStore, ticker_cmc_id, args)
      |> on_load(&history_price_on_load(&1, ticker_cmc_id, args))
    else
      error ->
        {:error, "Cannot fetch history price for #{slug}. Reason: #{inspect(error)}"}
    end
  end

  def ohlcv(_root, %{slug: slug} = args, %{context: %{loader: loader}}) do
    with ticker when not is_nil(ticker) <- Project.ticker_by_slug(slug) do
      ticker_cmc_id = ticker <> "_" <> slug

      loader
      |> Dataloader.load(PriceStore, ticker_cmc_id, args)
      |> on_load(&ohlcv_on_load(&1, ticker_cmc_id, args))
    else
      error ->
        {:error, "Cannot fetch history price for #{slug}. Reason: #{inspect(error)}"}
    end
  end

  # Private functions

  defp total_market_history_price_on_load(loader, args) do
    with {:ok, usd_prices} <- Dataloader.get(loader, PriceStore, @total_market_measurement, args) do
      result =
        usd_prices
        |> Enum.map(fn [dt, _, _, marketcap_usd, volume_usd] ->
          %{
            datetime: dt,
            marketcap: marketcap_usd,
            volume: volume_usd
          }
        end)

      {:ok, result}
    else
      _ ->
        {:error, "Can't fetch total marketcap prices"}
    end
  end

  defp history_price_on_load(loader, ticker_cmc_id, args) do
    with {:ok, prices} <- Dataloader.get(loader, PriceStore, ticker_cmc_id, args) do
      result =
        prices
        |> Enum.map(fn [dt, usd_price, btc_price, marketcap_usd, volume_usd] ->
          %{
            datetime: dt,
            price_btc: btc_price,
            price_usd: usd_price,
            marketcap: marketcap_usd,
            volume: volume_usd
          }
        end)

      {:ok, result}
    else
      _ ->
        {:error, "Can't fetch prices for #{ticker_cmc_id}"}
    end
  end

  defp ohlcv_on_load(loader, ticker_cmc_id, args) do
    with {:ok, prices} <- Dataloader.get(loader, PriceStore, ticker_cmc_id, args) do
      price_points =
        prices
        |> Enum.map(fn [dt, usd_price, btc_price, marketcap_usd, volume_usd] ->
          %{
            datetime: dt,
            price_btc: btc_price,
            price_usd: usd_price,
            marketcap: marketcap_usd,
            volume: volume_usd
          }
        end)

      usd_prices = prices |> Enum.map(fn [_, usd_price, _, _, _] -> usd_price end)
      btc_prices = prices |> Enum.map(fn [_, _, btc_price, _, _] -> btc_price end)

      {:ok,
       %{
         price_points: price_points,
         open_price_usd: usd_prices |> List.first(),
         high_price_usd: usd_prices |> Enum.max(),
         low_price_usd: usd_prices |> Enum.min(),
         close_price_usd: usd_prices |> List.last(),
         open_price_btc: btc_prices |> List.first(),
         high_price_btc: btc_prices |> Enum.max(),
         low_price_btc: btc_prices |> Enum.min(),
         close_price_btc: btc_prices |> List.last()
       }}
    else
      _ ->
        {:error, "Can't fetch prices for #{ticker_cmc_id}"}
    end
  end

  @deprecated "This should no longer be used after price by ticker is removed"
  def slug_by_ticker(ticker) do
    from(
      p in Project,
      where: p.ticker == ^ticker and not is_nil(p.coinmarketcap_id),
      select: p.coinmarketcap_id
    )
    |> Sanbase.Repo.one()
  end
end
