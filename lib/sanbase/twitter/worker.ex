defmodule Sanbase.Twitter.Worker do
  @moduledoc ~S"""
    A worker that regularly polls twitter for account data and stores it in
    a time series database.
  """

  @rate_limiter_name :twitter_api_rate_limiter

  use GenServer, restart: :permanent, shutdown: 5_000

  require Logger

  import Ecto.Query
  require Sanbase.Utils.Config, as: Config

  alias Sanbase.Repo
  alias Sanbase.Model.Project
  alias Sanbase.Influxdb.Measurement
  alias Sanbase.ExternalServices.RateLimiting.Server
  alias Sanbase.Twitter.Store

  @default_update_interval 1000 * 60 * 60 * 6

  def start_link(_state) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    :ok =
      ExTwitter.configure(
        consumer_key: Config.get(:consumer_key),
        consumer_secret: Config.get(:consumer_secret)
      )

    if Config.get(:sync_enabled, false) do
      Store.create_db()
      update_interval_ms = Config.get(:update_interval, @default_update_interval)

      GenServer.cast(self(), :sync)
      {:ok, %{update_interval_ms: update_interval_ms}}
    else
      :ignore
    end
  end

  def handle_cast(:sync, %{update_interval_ms: update_interval_ms} = state) do
    query =
      from(
        p in Project,
        select: p.twitter_link,
        where: not is_nil(p.twitter_link)
      )

    Task.Supervisor.async_stream_nolink(
      Sanbase.TaskSupervisor,
      Repo.all(query),
      &fetch_and_store(&1),
      ordered: false,
      # IO bound
      max_concurency: System.schedulers_online() * 2,
      # twitter api time window
      timeout: 15 * 1000 * 60
    )
    |> Stream.run()

    Process.send_after(self(), {:"$gen_cast", :sync}, update_interval_ms)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info("Unknown message received: #{msg}")
    {:noreply, state}
  end

  @doc ~S"""
  Stop the process from crashing on fetching fail and return nil
  """
  def fetch_twitter_user_data(twitter_name) do
    Server.wait(@rate_limiter_name)

    try do
      ExTwitter.user(twitter_name, include_entities: false)
    rescue
      _e in ExTwitter.RateLimitExceededError ->
        Logger.info("Rate limit to twitter exceeded.")
        fetch_twitter_user_data(twitter_name)
        nil

      e in ExTwitter.ConnectionError ->
        Logger.warn("Connection error while trying to fetch twitter user data: #{e.reason}")
        fetch_twitter_user_data(twitter_name)
        nil

      e in ExTwitter.Error ->
        Logger.warn("Error trying to fetch twitter user data for #{twitter_name}: #{e.message}")
        nil

      _ ->
        nil
    end
  end

  defp fetch_and_store("http://" <> rest), do: fetch_and_store("https://" <> rest)

  defp fetch_and_store("https://twitter.com/" <> twitter_name) do
    # Ignore trailing slash and everything after it
    twitter_name = String.split(twitter_name, "/") |> hd

    twitter_data_user_data = fetch_twitter_user_data(twitter_name)

    store_twitter_user_data(twitter_data_user_data, twitter_name)
    export_to_kafka(twitter_name, twitter_data_user_data)
  end

  defp fetch_and_store(args) do
    Logger.warn("Invalid parameters while fetching twitter data: " <> inspect(args))
  end

  defp export_to_kafka(twitter_handle, %ExTwitter.Model.User{followers_count: followers_count}) do
    topic = Config.module_get!(Sanbase.KafkaExporter, :twitter_followers_topic)

    Sanbase.Twitter.TimeseriesPoint.new(%{
      datetime: DateTime.utc_now(),
      twitter_handle: twitter_handle,
      followers_count: followers_count
    })
    |> Sanbase.Twitter.TimeseriesPoint.json_kv_tuple()
    |> List.wrap()
    |> Sanbase.KafkaExporter.send_data_to_topic_from_current_process(topic)
  end

  defp export_to_kafka(_twitter_handle, _), do: :ok

  defp store_twitter_user_data(nil, _twitter_name), do: :ok

  defp store_twitter_user_data(twitter_user_data, twitter_name) do
    if Application.get_env(:sanbase, :influx_store_enabled, true) do
      twitter_user_data
      |> convert_to_measurement(twitter_name)
      |> Store.import()
    end
  end

  defp convert_to_measurement(
         %ExTwitter.Model.User{followers_count: followers_count},
         measurement_name
       ) do
    %Measurement{
      timestamp: DateTime.to_unix(DateTime.utc_now(), :nanosecond),
      fields: %{followers_count: followers_count},
      tags: [],
      name: measurement_name
    }
  end
end
