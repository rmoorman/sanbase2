defmodule SanbaseWeb.Graphql.ProjectApiWalletTransactionsTest do
  use SanbaseWeb.ConnCase, async: false

  alias Sanbase.Influxdb.Measurement
  alias Sanbase.ExternalServices.Etherscan.Store

  alias Sanbase.Model.{
    Project,
    ProjectEthAddress
  }

  alias Sanbase.Repo

  import Mock
  import SanbaseWeb.Graphql.TestHelpers

  @datetime1 DateTime.from_naive!(~N[2017-05-13 15:00:00], "Etc/UTC")
  @datetime2 DateTime.from_naive!(~N[2017-05-14 16:00:00], "Etc/UTC")
  @datetime3 DateTime.from_naive!(~N[2017-05-15 17:00:00], "Etc/UTC")
  @datetime4 DateTime.from_naive!(~N[2017-05-16 18:00:00], "Etc/UTC")
  @datetime5 DateTime.from_naive!(~N[2017-05-17 19:00:00], "Etc/UTC")
  @datetime6 DateTime.from_naive!(~N[2017-05-18 20:00:00], "Etc/UTC")

  setup do
    Store.create_db()

    ticker = "TESTXYZ"
    Store.drop_measurement(ticker)

    p =
      %Project{}
      |> Project.changeset(%{name: "Santiment", ticker: ticker})
      |> Repo.insert!()

    %ProjectEthAddress{}
    |> ProjectEthAddress.changeset(%{
      project_id: p.id,
      address: "0x1"
    })
    |> Repo.insert!()

    %ProjectEthAddress{}
    |> ProjectEthAddress.changeset(%{
      project_id: p.id,
      address: "0x12345"
    })
    |> Repo.insert!()

    [
      project: p,
      ticker: ticker,
      datetime_from: @datetime1,
      datetime_to: @datetime6
    ]
  end

  test "project in transactions for the whole interval", context do
    with_mock Sanbase.Clickhouse.EthTransfers,
      top_wallet_transfers: fn _, _, _, _, _ ->
        {:ok, eth_transfers_in()}
      end do
      query = """
      {
        project(id: #{context.project.id}) {
          ethTopTransactions(
            from: "#{context.datetime_from}",
            to: "#{context.datetime_to}",
            transaction_type: IN){
              datetime,
              trxValue,
              fromAddress,
              toAddress
          }
        }
      }
      """

      result =
        context.conn
        |> post("/graphql", query_skeleton(query, "project"))

      trx_in = json_response(result, 200)["data"]["project"]["ethTopTransactions"]

      assert %{
               "datetime" => "2017-05-16T18:00:00Z",
               "fromAddress" => "0x2",
               "toAddress" => "0x1",
               "trxValue" => 20_000.0
             } in trx_in

      assert %{
               "datetime" => "2017-05-17T19:00:00Z",
               "fromAddress" => "0x2",
               "toAddress" => "0x1",
               "trxValue" => 45_000.0
             } in trx_in

      assert %{
               "datetime" => "2017-05-13T15:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 500.0
             } not in trx_in

      assert %{
               "datetime" => "2017-05-14T16:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 1500.0
             } not in trx_in
    end
  end

  test "project out transactions for the whole interval", context do
    with_mock Sanbase.Clickhouse.EthTransfers,
      top_wallet_transfers: fn _, _, _, _, _ ->
        {:ok, eth_transfers_out()}
      end do
      query = """
      {
        project(id: #{context.project.id}) {
          ethTopTransactions(
            from: "#{context.datetime_from}",
            to: "#{context.datetime_to}",
            transaction_type: OUT){
              datetime,
              trxValue,
              fromAddress,
              toAddress
          }
        }
      }
      """

      result =
        context.conn
        |> post("/graphql", query_skeleton(query, "project"))

      trx_out = json_response(result, 200)["data"]["project"]["ethTopTransactions"]

      assert %{
               "datetime" => "2017-05-13T15:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 500.0
             } in trx_out

      assert %{
               "datetime" => "2017-05-14T16:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 1500.0
             } in trx_out

      assert %{
               "datetime" => "2017-05-15T17:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 2500.0
             } in trx_out

      assert %{
               "datetime" => "2017-05-17T19:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 5500.0
             } in trx_out

      assert %{
               "datetime" => "2017-05-18T20:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 6500.0
             } in trx_out
    end
  end

  test "project all wallet transactions in interval", context do
    with_mock Sanbase.Clickhouse.EthTransfers,
      top_wallet_transfers: fn _, _, _, _, _ ->
        {:ok, eth_transfers_in() ++ eth_transfers_out()}
      end do
      query = """
      {
        project(id: #{context.project.id}) {
          ethTopTransactions(
            from: "#{context.datetime_from}",
            to: "#{context.datetime_to}",
            transaction_type: ALL){
              datetime,
              trxValue,
              fromAddress,
              toAddress
          }
        }
      }
      """

      result =
        context.conn
        |> post("/graphql", query_skeleton(query, "project"))

      trx_all = json_response(result, 200)["data"]["project"]["ethTopTransactions"]

      assert %{
               "datetime" => "2017-05-13T15:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 500.0
             } in trx_all

      assert %{
               "datetime" => "2017-05-14T16:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 1500.0
             } in trx_all

      assert %{
               "datetime" => "2017-05-15T17:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 2500.0
             } in trx_all

      assert %{
               "datetime" => "2017-05-16T18:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 3500.0
             } in trx_all

      assert %{
               "datetime" => "2017-05-17T19:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 5500.0
             } in trx_all

      assert %{
               "datetime" => "2017-05-18T20:00:00Z",
               "fromAddress" => "0x1",
               "toAddress" => "0x2",
               "trxValue" => 6500.0
             } in trx_all

      assert %{
               "datetime" => "2017-05-16T18:00:00Z",
               "fromAddress" => "0x2",
               "toAddress" => "0x1",
               "trxValue" => 20_000.0
             } in trx_all

      assert %{
               "datetime" => "2017-05-17T19:00:00Z",
               "fromAddress" => "0x2",
               "toAddress" => "0x1",
               "trxValue" => 45_000.0
             } in trx_all
    end
  end

  # Private functions

  defp eth_transfers_in() do
    [
      %Sanbase.Clickhouse.EthTransfers{
        blockNumber: 5_527_472,
        dt: @datetime4,
        from: "0x2",
        transactionPosition: 62,
        to: "0x1",
        transactionHash: "0xd4341953103d0d850d3284910213482dae5f7677c929f768d72f121e5a556fb3",
        value: 20_000 * :math.pow(10, 18)
      },
      %Sanbase.Clickhouse.EthTransfers{
        blockNumber: 5_569_715,
        dt: @datetime5,
        from: "0x2",
        transactionPosition: 7,
        to: "0x1",
        transactionHash: "0x31a5d24e2fa078b88b49bd1180f6b29dfe145bb51b6f98543fe9bccf6e15bba2",
        value: 45_000 * :math.pow(10, 18)
      }
    ]
  end

  defp eth_transfers_out() do
    [
      %Sanbase.Clickhouse.EthTransfers{
        blockNumber: 5_619_729,
        dt: @datetime1,
        from: "0x1",
        transactionPosition: 0,
        to: "0x2",
        transactionHash: "0x9a561c88bb59a1f6dfe63ed4fe036466b3a328d1d86d039377481ab7c4defe4e",
        value: 500 * :math.pow(10, 18)
      },
      %Sanbase.Clickhouse.EthTransfers{
        blockNumber: 5_769_021,
        dt: @datetime2,
        from: "0x1",
        transactionPosition: 2,
        to: "0x2",
        transactionHash: "0xccbb803caabebd3665eec49673e23ef5cd08bd0be50a2b1f1506d77a523827ce",
        value: 1500 * :math.pow(10, 18)
      },
      %Sanbase.Clickhouse.EthTransfers{
        blockNumber: 5_770_231,
        dt: @datetime3,
        from: "0x1",
        transactionPosition: 7,
        to: "0x2",
        transactionHash: "0x923f8054bf571ecd56db56f8aaf7b71b97f03ac7cf63e5cac929869cdbdd3863",
        value: 2500 * :math.pow(10, 18)
      },
      %Sanbase.Clickhouse.EthTransfers{
        blockNumber: 5_527_438,
        dt: @datetime4,
        from: "0x1",
        transactionPosition: 56,
        to: "0x2",
        transactionHash: "0xa891e1bbe292e546f40d23772b53a396ae2d37697665157bc6e019c647e9531a",
        value: 3500 * :math.pow(10, 18)
      },
      %Sanbase.Clickhouse.EthTransfers{
        blockNumber: 5_569_693,
        dt: @datetime5,
        from: "0x1",
        transactionPosition: 4,
        to: "0x2",
        transactionHash: "0x398772430a2e39f5f1addfbba56b7db1e30e5417de52c15001e157e350c18e52",
        value: 5500 * :math.pow(10, 18)
      },
      %Sanbase.Clickhouse.EthTransfers{
        blockNumber: 5_527_047,
        dt: @datetime6,
        from: "0x1",
        transactionPosition: 58,
        to: "0x2",
        transactionHash: "0xa99da23a274c33d40d950fbc03bee7330e518ef6a9622ddd818cb9b967f9f520",
        value: 6500 * :math.pow(10, 18)
      }
    ]
  end
end
