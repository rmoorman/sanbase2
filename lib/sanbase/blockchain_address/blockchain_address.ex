defmodule Sanbase.BlockchainAddress do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Sanbase.Model.Infrastructure

  schema "blockchain_addresses" do
    field(:address, :string)
    field(:notes, :string)

    belongs_to(:infrastructure, Infrastructure)
  end

  def changeset(%__MODULE__{} = addr, attrs \\ %{}) do
    addr
    |> cast(attrs, [:address, :infrastructure_id, :notes])
    |> validate_required([:address])
    |> validate_length(:notes, max: 45)
  end

  def by_id(id) do
    query = from(ba in __MODULE__, where: ba.id == ^id, preload: [:infrastructure])

    case Sanbase.Repo.one(query) do
      nil -> {:error, "Blockchain address with #{id} does not exist."}
      %__MODULE__{} = addr -> {:ok, addr}
    end
  end

  def by_selector(%{id: id}), do: by_id(id)

  def by_selector(%{infrastructure: infrastructure, address: address}) do
    with {:ok, %{id: infrastructure_id}} <- Sanbase.Model.Infrastructure.by_code(infrastructure),
         {:ok, addr} <-
           maybe_create(%{
             address: address,
             infrastructure_id: infrastructure_id
           }) do
      {:ok, addr}
    end
  end

  @doc ~s"""
  Convert an address to the internal format used in our databases.

  Ethereum addresses are case-insensitive - the upper and lower letters are used
  only for checks. Internally we store the addresses all downcased so they can be
  compared.

  All other chains are sensitive, so they are not changed by this function.
  """
  def to_internal_format(address) do
    cond do
      # ETH and ETH forks
      Regex.match?(~r/^0x([A-Fa-f0-9]{40})$/, address) -> String.downcase(address)
      # BTC and BTC forks
      Regex.match?(~r/^(bc1|[13])[a-zA-HJ-NP-Z0-9]{25,39}$/, address) -> address
      true -> address
    end
  end

  def maybe_create(%{address: _, infrastructure_id: _} = attrs) do
    case maybe_create([attrs]) do
      {:ok, [result]} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  def maybe_create(list) when is_list(list) do
    changesets = list |> Enum.map(&changeset(%__MODULE__{}, &1)) |> Enum.with_index()

    Enum.reduce(
      changesets,
      Ecto.Multi.new(),
      fn {changeset, offset}, multi ->
        # notes is an optional field. It should be replaced only if it is in the changeset
        notes_change = if Map.has_key?(changeset.changes, :notes), do: [:notes], else: []
        replace = notes_change ++ [:address, :infrastructure_id]

        multi
        |> Ecto.Multi.insert(offset, changeset,
          on_conflict: {:replace, replace},
          conflict_target: [:address, :infrastructure_id],
          returning: true
        )
      end
    )
    |> Sanbase.Repo.transaction()
    |> case do
      {:ok, result} -> {:ok, Map.values(result)}
      {:error, error} -> {:error, error}
    end
  end

  def blockchain_from_infrastructure("ETH"), do: "ethereum"
  def blockchain_from_infrastructure("BTC"), do: "bitcoin"
  def blockchain_from_infrastructure("BCH"), do: "bitcoin-cash"
  def blockchain_from_infrastructure("LTC"), do: "litecoin"
  def blockchain_from_infrastructure("BNB"), do: "binance"
  def blockchain_from_infrastructure("BEP2"), do: "binance"
  def blockchain_from_infrastructure("XRP"), do: "ripple"
  def blockchain_from_infrastructure(_), do: :unsupported_blockchain

  def infrastructure_from_blockchain("ethereum"), do: "ETH"
  def infrastructure_from_blockchain("bitcoin"), do: "BTC"
  def infrastructure_from_blockchain("bitcoin-cash"), do: "BCH"
  def infrastructure_from_blockchain("litecoin"), do: "LTC"
  def infrastructure_from_blockchain("binance"), do: "BEP2"
  def infrastructure_from_blockchain("ripple"), do: "XRP"
end
