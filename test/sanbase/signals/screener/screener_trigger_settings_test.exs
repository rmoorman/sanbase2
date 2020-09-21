defmodule Sanbase.Signal.ScreenerTriggerSettingsTest do
  use Sanbase.DataCase, async: false

  import Sanbase.Factory
  import Sanbase.TestHelpers
  import ExUnit.CaptureLog

  alias Sanbase.Signal.{UserTrigger, Trigger.ScreenerTriggerSettings}

  setup do
    # Clean children on exit, otherwise DB calls from async tasks can be attempted
    clean_task_supervisor_children()

    Sanbase.Signal.Evaluator.Cache.clear_all()

    user = insert(:user)
    Sanbase.Auth.UserSettings.set_telegram_chat_id(user.id, 123_123_123_123)

    selector = %{
      filters: [
        %{
          metric: "active_addresses_24h",
          dynamicFrom: "1d",
          dynamicTo: "now",
          operator: :greater_than,
          threshold: 500,
          aggregation: :last
        }
      ]
    }

    watchlist = insert(:watchlist, %{user: user, function: %{name: "selector", args: selector}})

    settings_selector = %{
      type: "screener_signal",
      operation: %{selector: selector},
      channel: "telegram"
    }

    settings_watchlist = %{
      type: "screener_signal",
      operation: %{selector: %{watchlist_id: watchlist.id}},
      channel: "telegram"
    }

    %{
      user: user,
      settings_selector: settings_selector,
      settings_watchlist: settings_watchlist,
      p1: insert(:random_project),
      p2: insert(:random_project),
      p3: insert(:random_project),
      p4: insert(:random_project),
      p5: insert(:random_project)
    }
  end

  test "enter/exit screener with selector", context do
    %{user: user, settings_selector: settings_selector, p1: p1, p2: p2, p3: p3, p4: p4, p5: p5} =
      context

    # On post create processing add p1, p2 and p3.
    # On the first evaluation the trigger should be fired as there are changes.
    # On the second evaluation the trigger should not be fired as there are no changes
    mock_fun =
      [
        fn -> {:ok, [p1.slug, p2.slug, p3.slug]} end,
        fn -> {:ok, [p3.slug, p4.slug, p5.slug]} end,
        fn -> {:ok, [p3.slug, p4.slug, p5.slug]} end
      ]
      |> Sanbase.Mock.wrap_consecutives(arity: 6)

    Sanbase.Mock.prepare_mock(Sanbase.Clickhouse.Metric, :slugs_by_filter, mock_fun)
    |> Sanbase.Mock.prepare_mock2(&Sanbase.Telegram.send_message/2, :ok)
    |> Sanbase.Mock.run_with_mocks(fn ->
      # After creation the post create processing adds p1, p2 and p3 to the state.
      # 0s cooldown so it can be re-run in order to test the behaviour when
      # the state did not hange
      {:ok, _user_trigger} =
        UserTrigger.create_user_trigger(user, %{
          title: "Generic title",
          is_public: true,
          cooldown: "0s",
          settings: settings_selector
        })

      # Clear the result of the filter
      Sanbase.Cache.clear_all()
      Sanbase.Signal.Evaluator.Cache.clear_all()

      # First run
      assert capture_log(fn ->
               Sanbase.Signal.Scheduler.run_signal(ScreenerTriggerSettings)
             end) =~ "In total 1/1 screener_signal signals were sent successfully"

      # Clear the result of the filter
      Sanbase.Cache.clear_all()
      Sanbase.Signal.Evaluator.Cache.clear_all()

      # Second run
      assert capture_log(fn ->
               Sanbase.Signal.Scheduler.run_signal(ScreenerTriggerSettings)
             end) =~ "There were no screener_signal signals triggered"
    end)
  end

  test "enter/exit screener with watchlist", context do
    %{user: user, settings_watchlist: settings_watchlist, p1: p1, p2: p2, p3: p3, p4: p4, p5: p5} =
      context

    # On post create processing add p1, p2 and p3.
    # On the first evaluation the trigger should be fired as there are changes.
    # On the second evaluation the trigger should not be fired as there are no changes
    mock_fun =
      [
        fn -> {:ok, [p1.slug, p2.slug, p3.slug]} end,
        fn -> {:ok, [p3.slug, p4.slug, p5.slug]} end,
        fn -> {:ok, [p3.slug, p4.slug, p5.slug]} end
      ]
      |> Sanbase.Mock.wrap_consecutives(arity: 6)

    Sanbase.Mock.prepare_mock(Sanbase.Clickhouse.Metric, :slugs_by_filter, mock_fun)
    |> Sanbase.Mock.prepare_mock2(&Sanbase.Telegram.send_message/2, :ok)
    |> Sanbase.Mock.run_with_mocks(fn ->
      # After creation the post create processing adds p1, p2 and p3 to the state.
      # 0s cooldown so it can be re-run in order to test the behaviour when
      # the state did not hange
      {:ok, _user_trigger} =
        UserTrigger.create_user_trigger(user, %{
          title: "Generic title",
          is_public: true,
          cooldown: "0s",
          settings: settings_watchlist
        })

      # Clear the result of the filter
      Sanbase.Cache.clear_all()
      Sanbase.Signal.Evaluator.Cache.clear_all()

      # First run
      assert capture_log(fn ->
               Sanbase.Signal.Scheduler.run_signal(ScreenerTriggerSettings)
             end) =~ "In total 1/1 screener_signal signals were sent successfully"

      # Clear the result of the filter
      Sanbase.Cache.clear_all()
      Sanbase.Signal.Evaluator.Cache.clear_all()

      # Second run
      assert capture_log(fn ->
               Sanbase.Signal.Scheduler.run_signal(ScreenerTriggerSettings)
             end) =~ "There were no screener_signal signals triggered"
    end)
  end
end
