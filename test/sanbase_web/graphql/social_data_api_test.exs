defmodule Sanbase.SocialDataApiTest do
  use SanbaseWeb.ConnCase, async: false

  import Mockery
  import ExUnit.CaptureLog
  import SanbaseWeb.Graphql.TestHelpers

  test "successfully fetch social data", %{conn: conn} do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body:
           "[{\"timestamp\": 1541808000, \"top_words\": {\"bat\": 367.77770422285084, \"pele\": 167.74716011726295, \"people\": 137.61557511242117, \"arn\": 137.14962816454351, \"chimeracryptoinsider\": 118.17637249353709}}, {\"timestamp\": 1541721600, \"top_words\": {\"bat\": 1740.2647984845628, \"xlm\": 837.0034350090417, \"coinbase\": 792.9209638684719, \"mth\": 721.8164660673655, \"mana\": 208.48182966076172}}, {\"timestamp\": 1541980800, \"top_words\": {\"xlm\": 769.8008634834883, \"bch\": 522.9358622900285, \"fork\": 340.17719444024317, \"mda\": 213.57227498303558, \"abc\": 177.6092706156777}}, {\"timestamp\": 1541894400, \"top_words\": {\"mana\": 475.8978759407794, \"mth\": 411.73069246798326, \"fork\": 321.11991967479867, \"bch\": 185.35627662699594, \"imgur\": 181.45123778369867}}]",
         status_code: 200
       }}
    )

    query = """
    {
      trendingWords(
        source: TELEGRAM,
        size: 5,
        hour: 8,
        from: "2018-11-05T00:00:00Z",
        to: "2018-11-12T00:00:00Z"){
          datetime
          topWords{
            word
            score
          }
        }
      }
    """

    # As the HTTP call is mocked these arguemnts do no have much effect, though you should try to put the real ones that are used
    result =
      conn
      |> post("/graphql", query_skeleton(query, "trendingWords"))
      |> json_response(200)

    assert result == %{
             "data" => %{
               "trendingWords" => [
                 %{
                   "datetime" => "2018-11-10T00:00:00Z",
                   "topWords" => [
                     %{"score" => 137.14962816454351, "word" => "arn"},
                     %{"score" => 367.77770422285084, "word" => "bat"},
                     %{
                       "score" => 118.17637249353709,
                       "word" => "chimeracryptoinsider"
                     },
                     %{"score" => 167.74716011726295, "word" => "pele"},
                     %{"score" => 137.61557511242117, "word" => "people"}
                   ]
                 },
                 %{
                   "datetime" => "2018-11-09T00:00:00Z",
                   "topWords" => [
                     %{"score" => 1740.2647984845628, "word" => "bat"},
                     %{"score" => 792.9209638684719, "word" => "coinbase"},
                     %{"score" => 208.48182966076172, "word" => "mana"},
                     %{"score" => 721.8164660673655, "word" => "mth"},
                     %{"score" => 837.0034350090417, "word" => "xlm"}
                   ]
                 },
                 %{
                   "datetime" => "2018-11-12T00:00:00Z",
                   "topWords" => [
                     %{"score" => 177.6092706156777, "word" => "abc"},
                     %{"score" => 522.9358622900285, "word" => "bch"},
                     %{"score" => 340.17719444024317, "word" => "fork"},
                     %{"score" => 213.57227498303558, "word" => "mda"},
                     %{"score" => 769.8008634834883, "word" => "xlm"}
                   ]
                 },
                 %{
                   "datetime" => "2018-11-11T00:00:00Z",
                   "topWords" => [
                     %{"score" => 185.35627662699594, "word" => "bch"},
                     %{"score" => 321.11991967479867, "word" => "fork"},
                     %{"score" => 181.45123778369867, "word" => "imgur"},
                     %{"score" => 475.8978759407794, "word" => "mana"},
                     %{"score" => 411.73069246798326, "word" => "mth"}
                   ]
                 }
               ]
             }
           }
  end

  test "error fetching social data", %{conn: conn} do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body: "Internal Server Error",
         status_code: 500
       }}
    )

    query = """
    {
      trendingWords(
        source: TELEGRAM,
        size: 5,
        hour: 8,
        from: "2018-11-05T00:00:00Z",
        to: "2018-11-12T00:00:00Z"){
          datetime
          topWords{
            word
            score
          }
        }
      }
    """

    result_fn = fn ->
      result =
        conn
        |> post("/graphql", query_skeleton(query, "trendingWords"))
        |> json_response(200)

      error = result["errors"] |> List.first()
      assert error["message"] =~ "Error executing query. See logs for details."
    end

    assert capture_log(result_fn) =~
             "Error status 500 fetching trending words for source: telegram: Internal Server Error"
  end

  test "successfully fetch word context", %{conn: conn} do
    body =
      %{
        "christ" => %{"score" => 0.7688603531300161},
        "christmas" => %{"score" => 0.7592295345104334},
        "mas" => %{"score" => 1.0}
      }
      |> Jason.encode!()

    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body: body,
         status_code: 200
       }}
    )

    query = """
    {
      wordContext(
        word: "merry", 
        source: TELEGRAM,
        size: 3,
        from: "2018-12-22T00:00:00Z",
        to:"2018-12-27T00:00:00Z"
      ) {
        word
        score
      }
    }
    """

    result =
      conn
      |> post("/graphql", query_skeleton(query, "wordContext"))
      |> json_response(200)

    assert result == %{
             "data" => %{
               "wordContext" => [
                 %{"score" => 1.0, "word" => "mas"},
                 %{"score" => 0.7688603531300161, "word" => "christ"},
                 %{"score" => 0.7592295345104334, "word" => "christmas"}
               ]
             }
           }
  end

  test "error 500 when fetch word context from tech-indicators", %{conn: conn} do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body: "Internal Server Error",
         status_code: 500
       }}
    )

    query = """
    {
      wordContext(
        word: "merry", 
        source: TELEGRAM,
        size: 3,
        from: "2018-12-22T00:00:00Z",
        to:"2018-12-27T00:00:00Z"
      ) {
        word
        score
      }
    }
    """

    result_fn = fn ->
      conn
      |> post("/graphql", query_skeleton(query, "wordTrendScore"))
      |> json_response(200)
    end

    assert capture_log(result_fn) =~
             "Error status 500 fetching word context for word merry: Internal Server Error"
  end

  test "successfully fetch word trend score", %{conn: conn} do
    body =
      [
        %{
          "hour" => 8.0,
          "score" => 3725.6617392595313,
          "source" => "telegram",
          "timestamp" => 1_547_078_400
        }
      ]
      |> Jason.encode!()

    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body: body,
         status_code: 200
       }}
    )

    query = """
    {
      wordTrendScore(
        word: "merry", 
        source: TELEGRAM,
        from: "2018-01-09T00:00:00Z",
        to:"2018-01-10T00:00:00Z"
      ) {
        datetime,
        score,
        source
      }
    }
    """

    result =
      conn
      |> post("/graphql", query_skeleton(query, "wordTrendScore"))
      |> json_response(200)

    assert result == %{
             "data" => %{
               "wordTrendScore" => [
                 %{
                   "score" => 3725.6617392595313,
                   "source" => "TELEGRAM",
                   "datetime" => "2019-01-10T08:00:00Z"
                 }
               ]
             }
           }
  end

  test "error 500 when fetch word trend score from tech-indicators", %{conn: conn} do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body: "Internal Server Error",
         status_code: 500
       }}
    )

    query = """
    {
      wordTrendScore(
        word: "merry", 
        source: TELEGRAM,
        from: "2018-01-09T00:00:00Z",
        to:"2018-01-10T00:00:00Z"
      ) {
        datetime,
        score,
        source
      }
    }
    """

    result_fn = fn ->
      conn
      |> post("/graphql", query_skeleton(query, "wordTrendScore"))
      |> json_response(200)
    end

    assert capture_log(result_fn) =~
             "Error status 500 fetching word trend score for word merry: Internal Server Error"
  end

  test "successfully fetch top social gainers losers", %{conn: conn} do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body:
           "[{\"timestamp\": 1552654800, \"range\": \"15d\", \"projects\": [{\"project\": \"qtum\", \"change\": 137.13186813186815, \"status\": \"gainer\"}, {\"project\": \"abbc-coin\", \"change\": -1.0, \"status\": \"loser\"}]}]",
         status_code: 200
       }}
    )

    query = """
    {
      topSocialGainersLosers(
        status: ALL, 
        from: "2018-01-09T00:00:00Z",
        to:"2018-01-10T00:00:00Z",
        range: "15d",
        size: 1
      ) {
        datetime,
        projects {
          project,
          change,
          status
        }
      }
    }
    """

    result =
      conn
      |> post("/graphql", query_skeleton(query, "topSocialGainersLosers"))
      |> json_response(200)

    assert result == %{
             "data" => %{
               "topSocialGainersLosers" => [
                 %{
                   "datetime" => "2019-03-15T13:00:00Z",
                   "projects" => [
                     %{
                       "change" => 137.13186813186815,
                       "project" => "qtum",
                       "status" => "GAINER"
                     },
                     %{
                       "change" => -1.0,
                       "project" => "abbc-coin",
                       "status" => "LOSER"
                     }
                   ]
                 }
               ]
             }
           }
  end

  test "error 500 when fetch top social gainers losers from tech-indicators", %{conn: conn} do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body: "Internal Server Error",
         status_code: 500
       }}
    )

    query = """
    {
      topSocialGainersLosers(
        status: ALL, 
        from: "2018-01-09T00:00:00Z",
        to:"2018-01-10T00:00:00Z",
        range: "15d",
        size: 1
      ) {
        datetime,
        projects {
          project,
          change,
          status
        }
      }
    }
    """

    result_fn = fn ->
      conn
      |> post("/graphql", query_skeleton(query, "topSocialGainersLosers"))
      |> json_response(200)
    end

    assert capture_log(result_fn) =~
             "Error status 500 fetching top social gainers losers for status: all: Internal Server Error"
  end

  test "successfully fetch social gainers losers status for slug", %{conn: conn} do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body:
           "[{\"timestamp\": 1552662000, \"status\": \"gainer\", \"change\": 12.709016393442624}]",
         status_code: 200
       }}
    )

    query = """
    {
      socialGainersLosersStatus(
        slug: "qtum",
        from: "2018-01-09T00:00:00Z",
        to:"2018-01-10T00:00:00Z",
        range: "15d",
      ) {
        datetime,
        change,
        status
      }
    }
    """

    result =
      conn
      |> post("/graphql", query_skeleton(query, "socialGainersLosersStatus"))
      |> json_response(200)

    assert result == %{
             "data" => %{
               "socialGainersLosersStatus" => [
                 %{
                   "change" => 12.709016393442624,
                   "datetime" => "2019-03-15T15:00:00Z",
                   "status" => "GAINER"
                 }
               ]
             }
           }
  end

  test "error 500 when fetch social gainers losers status from tech-indicators", %{conn: conn} do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body: "Internal Server Error",
         status_code: 500
       }}
    )

    query = """
    {
      socialGainersLosersStatus(
        slug: "qtum",
        from: "2018-01-09T00:00:00Z",
        to:"2018-01-10T00:00:00Z",
        range: "15d",
      ) {
        datetime,
        change,
        status
      }
    }
    """

    result_fn = fn ->
      conn
      |> post("/graphql", query_skeleton(query, "socialGainersLosersStatus"))
      |> json_response(200)
    end

    assert capture_log(result_fn) =~
             "Error status 500 fetching social gainers losers status for slug: qtum: Internal Server Error"
  end
end
