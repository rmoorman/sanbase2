defmodule SanbaseWeb.Graphql.Clickhouse.MVRVTest do
  use SanbaseWeb.ConnCase, async: false

  import SanbaseWeb.Graphql.TestHelpers
  import Mock
  import ExUnit.CaptureLog
  import Sanbase.Factory

  alias Sanbase.Clickhouse.MVRV

  setup do
    project = insert(:project, %{coinmarketcap_id: "ethereum", ticker: "ETH"})

    [
      slug: project.coinmarketcap_id,
      from: allowed_free_user_from(),
      to: allowed_free_user_to(),
      interval: "1d"
    ]
  end

  test "returns data from MVRV calculation", context do
    with_mock MVRV,
      mvrv_ratio: fn _, _, _, _ ->
        {:ok,
         [
           %{ratio: 0.1, datetime: allowed_free_user_from()},
           %{ratio: 0.2, datetime: Timex.shift(allowed_free_user_from(), days: 1)}
         ]}
      end do
      response = execute_query(context)
      ratios = parse_response(response)

      assert_called(MVRV.mvrv_ratio(context.slug, context.from, context.to, context.interval))

      assert ratios == [
               %{"ratio" => 0.1, "datetime" => DateTime.to_iso8601(allowed_free_user_from())},
               %{
                 "ratio" => 0.2,
                 "datetime" => DateTime.to_iso8601(Timex.shift(allowed_free_user_from(), days: 1))
               }
             ]
    end
  end

  test "returns empty array when there is no data", context do
    with_mock MVRV, mvrv_ratio: fn _, _, _, _ -> {:ok, []} end do
      response = execute_query(context)
      ratios = parse_response(response)

      assert_called(MVRV.mvrv_ratio(context.slug, context.from, context.to, context.interval))
      assert ratios == []
    end
  end

  test "logs warning when calculation errors", context do
    with_mock MVRV,
      mvrv_ratio: fn _, _, _, _ -> {:error, "Some error description here"} end do
      assert capture_log(fn ->
               response = execute_query(context)
               ratios = parse_response(response)
               assert ratios == nil
             end) =~
               ~s/[warn] Can't calculate MVRV ratio for project with coinmarketcap_id: ethereum. Reason: "Some error description here"/
    end
  end

  test "uses 1d as default interval", context do
    with_mock MVRV, mvrv_ratio: fn _, _, _, _ -> {:ok, []} end do
      query = """
        {
          mvrvRatio(slug: "#{context.slug}", from: "#{context.from}", to: "#{context.to}"){
            datetime,
            ratio
          }
        }
      """

      context.conn
      |> post("/graphql", query_skeleton(query, "mvrvRatio"))

      assert_called(MVRV.mvrv_ratio(context.slug, context.from, context.to, "1d"))
    end
  end

  defp parse_response(response) do
    json_response(response, 200)["data"]["mvrvRatio"]
  end

  defp execute_query(context) do
    query = mvrv_query(context.slug, context.from, context.to, context.interval)

    context.conn
    |> post("/graphql", query_skeleton(query, "mvrvRatio"))
  end

  defp mvrv_query(slug, from, to, interval) do
    """
      {
        mvrvRatio(slug: "#{slug}", from: "#{from}", to: "#{to}", interval: "#{interval}"){
          datetime,
          ratio
        }
      }
    """
  end
end
