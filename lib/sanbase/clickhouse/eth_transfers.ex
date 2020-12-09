defmodule Sanbase.Clickhouse.EthTransfers do
  @moduledoc ~s"""
  Uses ClickHouse to work with ETH transfers.
  """

  use Ecto.Schema

  import Sanbase.Utils.Transform

  alias Sanbase.ClickhouseRepo

  require Logger

  @type t :: %__MODULE__{
          datetime: %DateTime{},
          from_address: String.t(),
          to_address: String.t(),
          trx_hash: String.t(),
          trx_value: float,
          block_number: non_neg_integer,
          trx_position: non_neg_integer,
          type: String.t()
        }

  @type wallets :: list(String.t())

  @table "eth_transfers"
  @eth_decimals 1_000_000_000_000_000_000

  @primary_key false
  @timestamps_opts [updated_at: false]
  schema @table do
    field(:datetime, :utc_datetime, source: :dt)
    field(:from_address, :string, primary_key: true, source: :from)
    field(:to_address, :string, primary_key: true, source: :to)
    field(:trx_hash, :string, source: :transactionHash)
    field(:trx_value, :float, source: :value)
    field(:block_number, :integer, source: :blockNumber)
    field(:trx_position, :integer, source: :transactionPosition)
    field(:type, :string)
  end

  @spec changeset(any(), any()) :: no_return()
  def changeset(_, _) do
    raise "Should not try to change eth transfers"
  end

  @doc ~s"""
  Return the `limit` biggest transfers for a list of wallets and time period.
  Only transfers which `from` address is in the list and `to` address is
  not in the list are selected.
  """
  @spec top_wallet_transfers(wallets, %DateTime{}, %DateTime{}, integer, String.t()) ::
          {:ok, nil} | {:ok, list(t)} | {:error, String.t()}
  def top_wallet_transfers([], _from, _to, _limit, _type), do: {:ok, []}

  def top_wallet_transfers(wallets, from, to, limit, type) do
    {query, args} = wallet_transactions_query(wallets, from, to, limit, type)

    ClickhouseRepo.query_transform(query, args, fn
      [timestamp, from_address, to_address, trx_hash, trx_value] ->
        %{
          datetime: DateTime.from_unix!(timestamp),
          from_address: maybe_transform_from_address(from_address),
          to_address: maybe_transform_to_address(to_address),
          trx_hash: trx_hash,
          trx_value: trx_value
        }
    end)
  end

  @spec eth_top_transactions(%DateTime{}, %DateTime{}, integer) ::
          {:ok, nil} | {:ok, list(t)} | {:error, String.t()}
  def eth_top_transactions(from, to, limit) do
    {query, args} = eth_top_transactions_query(from, to, limit)

    ClickhouseRepo.query_transform(query, args, fn
      [timestamp, from_address, to_address, trx_hash, trx_value] ->
        %{
          datetime: DateTime.from_unix!(timestamp),
          from_address: maybe_transform_from_address(from_address),
          to_address: maybe_transform_to_address(to_address),
          trx_hash: trx_hash,
          trx_value: trx_value / @eth_decimals
        }
    end)
  end

  @spec eth_2_staking_transactions(%DateTime{}, %DateTime{}, integer) ::
          {:ok, nil} | {:ok, list(t)} | {:error, String.t()}
  def eth_2_staking_transactions(from, to, limit) do
    {query, args} = eth_2_staking_transactions_query(from, to, limit)

    ClickhouseRepo.query_transform(query, args, fn
      [timestamp, address, trx_hash, trx_value] ->
        %{
          datetime: DateTime.from_unix!(timestamp),
          from_address: address,
          to_address: '0x',
          trx_hash: '0x',
          trx_value: trx_value
        }
    end)
  end

  # Private functions

  defp eth_2_staking_transactions_query(from, to) do
    query = """
    SELECT
      toUnixTimestamp(dt),
      from,
      to,
      transactionHash,
      value / #{@eth_decimals}
    FROM eth2_staking_transfers_mv
    PREWHERE
      dt >= toDateTime(?1) AND
      dt <= toDateTime(?2) AND
      type = 'call'
    ORDER BY value DESC
    """

    args = [
      from |> DateTime.to_unix(),
      to |> DateTime.to_unix(),
    ]

    {query, args}
  end
  
  defp wallet_transactions_query(wallets, from, to, limit, :out) do
    query = """
    SELECT
      toUnixTimestamp(dt),
      from,
      to,
      transactionHash,
      value / #{@eth_decimals}
    FROM #{@table} FINAL
    PREWHERE
      from IN (?1) AND
      NOT to IN (?1) AND
      dt >= toDateTime(?2) AND
      dt <= toDateTime(?3) AND
      type = 'call'
    ORDER BY value DESC
    LIMIT ?4
    """

    args = [
      wallets,
      from |> DateTime.to_unix(),
      to |> DateTime.to_unix(),
      limit
    ]

    {query, args}
  end

  defp wallet_transactions_query(wallets, from, to, limit, :in) do
    query = """
    SELECT
      toUnixTimestamp(dt),
      from,
      to,
      transactionHash,
      value / #{@eth_decimals}
    FROM #{@table} FINAL
    PREWHERE
      from NOT IN (?1) AND
      to IN (?1) AND
      dt >= toDateTime(?2) AND
      dt <= toDateTime(?3) AND
      type = 'call'
    ORDER BY value DESC
    LIMIT ?4
    """

    args = [
      wallets,
      from |> DateTime.to_unix(),
      to |> DateTime.to_unix(),
      limit
    ]

    {query, args}
  end

  defp wallet_transactions_query(wallets, from, to, limit, :all) do
    query = """
    SELECT
      toUnixTimestamp(dt),
      from,
      to,
      transactionHash,
      value / #{@eth_decimals}
    FROM #{@table} FINAL
    PREWHERE
      (
        (from IN (?1) AND NOT to IN (?1)) OR
        (NOT from IN (?1) AND to IN (?1))
      ) AND
      dt >= toDateTime(?2) AND
      dt <= toDateTime(?3) AND
      type = 'call'
    ORDER BY value DESC
    LIMIT ?4
    """

    args = [
      wallets,
      from |> DateTime.to_unix(),
      to |> DateTime.to_unix(),
      limit
    ]

    {query, args}
  end

  defp eth_top_transactions_query(from, to, limit) do
    from_unix = DateTime.to_unix(from)
    to_unix = DateTime.to_unix(to)

    # only > 10K ETH transfers if range is > 1 week, otherwise only bigger than 1K
    value_filter = if Timex.diff(to, from, :days) > 7, do: 10_000, else: 1_000

    query = """
    SELECT
      toUnixTimestamp(dt), from, to, transactionHash, value
    FROM #{@table} FINAL
    PREWHERE
      value > ?1 AND
      type = 'call' AND
      dt >= toDateTime(?2) AND
      dt <= toDateTime(?3)
    ORDER BY value DESC
    LIMIT ?4
    """

    args = [
      value_filter,
      from_unix,
      to_unix,
      limit
    ]

    {query, args}
  end
end
