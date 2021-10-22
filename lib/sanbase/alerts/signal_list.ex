defmodule Sanbase.Alert.List do
  alias Sanbase.Alert.Trigger

  def get() do
    [
      Trigger.DailyMetricTriggerSettings,
      Trigger.EthWalletTriggerSettings,
      Trigger.MetricTriggerSettings,
      Trigger.ScreenerTriggerSettings,
      Trigger.TrendingWordsTriggerSettings,
      Trigger.WalletTriggerSettings,
      Trigger.SignalTriggerSettings
    ]
  end
end
