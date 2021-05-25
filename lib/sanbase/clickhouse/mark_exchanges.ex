defmodule Sanbase.Clickhouse.MarkExchanges do
  @moduledoc ~s"""
  Used to transform a list of transactions in the form of `input_transaction` type
  to `output_transaction` type.
  """

  @type input_transaction :: %{
          from_address: String.t(),
          to_address: String.t(),
          trx_value: float,
          trx_hash: String.t(),
          datetime: Datetime.t()
        }

  @type output_transaction :: %{
          from_address: %{
            address: String.t(),
            is_exhange: boolean
          },
          to_address: %{
            address: String.t(),
            is_exhange: boolean
          },
          trx_value: float,
          trx_hash: String,
          datetime: Datetime.t()
        }

  use GenServer

  @refresh_interval_min 10
  @name :mark_exchange_wallets_gen_server

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    {:ok, %{}, {:continue, :set_state}}
  end

  def handle_continue(:set_state, _) do
    {:noreply, fill_state()}
  end

  @doc ~s"""
  Transform a list of transactions where the `from_address` and `to_address` are strings
  to a list of transactions where the `from_address` and `to_address` are compound
  fields with `address` string and `is_exchange` boolean fields
  """
  @spec mark_exchange_wallets(list(input_transaction)) :: {:ok, list(output_transaction)}
  def mark_exchange_wallets([]), do: {:ok, []}

  def mark_exchange_wallets(transactions) when is_list(transactions) do
    GenServer.call(@name, :update_state_if_staled)
    GenServer.call(@name, {:mark_exchange_wallets, transactions})
  end

  def handle_call(
        {:mark_exchange_wallets, transactions},
        _from,
        %{exchange_wallets_set: exchanges} = state
      ) do
    marked_exchange_transactions =
      transactions
      |> Enum.map(fn
        %{from_address: nil, to_address: to} = transaction ->
          %{
            transaction
            | to_address: %{
                address: to,
                is_exchange: MapSet.member?(exchanges, to)
              }
          }

        %{from_address: from, to_address: nil} = transaction ->
          %{
            transaction
            | from_address: %{
                address: from,
                is_exchange: MapSet.member?(exchanges, from)
              }
          }

        %{from_address: from, to_address: to} = transaction ->
          %{
            transaction
            | from_address: %{
                address: from,
                is_exchange: MapSet.member?(exchanges, from)
              },
              to_address: %{
                address: to,
                is_exchange: MapSet.member?(exchanges, to)
              }
          }
      end)

    {:reply, {:ok, marked_exchange_transactions}, state}
  end

  def handle_call(:update_state_if_staled, _from, %{updated_at: updated_at} = state) do
    if Timex.diff(Timex.now(), updated_at, :minutes) >= @refresh_interval_min do
      {:reply, :ok, state, {:continue, :set_state}}
    else
      {:reply, :ok, state}
    end
  end

  @doc false
  def handle_call(
        {:add_exchange_wallets, wallets},
        _from,
        %{exchange_wallets_set: exchanges} = state
      ) do
    new_state = %{state | exchange_wallets_set: MapSet.union(exchanges, MapSet.new(wallets))}
    {:reply, :ok, new_state}
  end

  def handle_info(:set_state, _) do
    {:noreply, fill_state()}
  end

  @doc false
  def add_exchange_wallets(wallets) when is_list(wallets) do
    # Used to add new exchange wallet addresses. Used only from within tests
    GenServer.call(@name, {:add_exchange_wallets, wallets})
  end

  defp fill_state() do
    ch_repo_enabled? = Sanbase.ClickhouseRepo.enabled?()
    env = Application.get_env(:sanbase, :env)

    case ch_repo_enabled? and env != :test do
      true -> do_fill_state()
      false -> %{exchange_wallets_set: MapSet.new(), updated_at: Timex.now()}
    end
  end

  defp do_fill_state() do
    case Sanbase.Clickhouse.ExchangeAddress.exchange_addresses("ethereum") do
      {:ok, addresses} ->
        mapset = addresses |> Enum.map(& &1.address) |> MapSet.new(&String.downcase/1)

        Map.put(%{}, :exchange_wallets_set, mapset)
        |> Map.put(:updated_at, Timex.now())

      _ ->
        # Try to fill the state after 5 seconds
        Process.send_after(self(), :set_state, 5_000)

        Map.put(%{}, :exchange_wallets_set, MapSet.new())
        |> Map.put(:updated_at, Timex.now())
    end
  end
end
