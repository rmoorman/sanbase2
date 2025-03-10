defmodule Sanbase.Billing.MetricAccessLevelTest do
  use ExUnit.Case, async: true

  setup do
    metrics_access_map = Sanbase.Metric.access_map()

    %{metrics_access_map: metrics_access_map}
  end

  test "free metrics", %{metrics_access_map: access_map} do
    free_metrics =
      Sanbase.Billing.GraphqlSchema.get_with_access_level(access_map, :free)
      |> Enum.sort()

    expected_free_metrics =
      [
        "active_addresses_24h",
        "active_addresses_1h",
        "circulation",
        "daily_active_addresses",
        "daily_avg_marketcap_usd",
        "daily_avg_price_usd",
        "daily_closing_marketcap_usd",
        "daily_closing_price_usd",
        "daily_high_price_usd",
        "daily_low_price_usd",
        "daily_opening_price_usd",
        "daily_trading_volume_usd",
        "dev_activity",
        "dev_activity_1d",
        "30d_moving_avg_dev_activity_change_1d",
        "github_activity",
        "dev_activity_contributors_count",
        "github_activity_contributors_count",
        "historical_balance",
        "historical_balance_changes",
        "marketcap_usd",
        "price_btc",
        "price_usd",
        "price_eth",
        "price_usd_5m",
        "volume_usd",
        "twitter_followers",
        "total_supply",
        "mcd_erc20_supply",
        "rank",
        # change metrics
        "volume_usd_change_1d",
        "volume_usd_change_7d",
        "volume_usd_change_30d",
        "price_usd_change_1d",
        "price_usd_change_7d",
        "price_usd_change_30d",
        "active_addresses_24h_change_1d",
        "active_addresses_24h_change_7d",
        "active_addresses_24h_change_30d",
        "dev_activity_change_1d",
        "dev_activity_change_7d",
        "dev_activity_change_30d",
        "marketcap_usd_change_1d",
        "marketcap_usd_change_7d",
        "marketcap_usd_change_30d",
        # Uniswap
        "uniswap_total_claims_amount",
        "uniswap_claims_amount",
        "uniswap_claims_count",
        "uniswap_total_claims_count",
        "uniswap_lp_claims_amount",
        "uniswap_lp_claims_count",
        "uniswap_total_claims_percent",
        "uniswap_total_lp_claims_amount",
        "uniswap_total_lp_claims_count",
        "uniswap_total_user_claims_amount",
        "uniswap_total_user_claims_count",
        "uniswap_user_claims_amount",
        "uniswap_user_claims_count",
        # histogram metrics
        "eth2_staked_amount_per_label",
        "eth2_staked_address_count_per_label",
        "eth2_unlabeled_staker_inflow_sources",
        "eth2_top_stakers",
        "price_usd_change_1h",
        "price_eth_change_1d",
        "price_eth_change_7d",
        "price_eth_change_30d",
        "price_btc_change_1d",
        "price_btc_change_7d",
        "price_btc_change_30d"
      ]
      |> Enum.sort()

    assert free_metrics == expected_free_metrics
  end

  test "restricted metrics", %{metrics_access_map: access_map} do
    restricted_metrics =
      Sanbase.Billing.GraphqlSchema.get_with_access_level(access_map, :restricted)
      |> Enum.sort()

    expected_restricted_metrics =
      [
        "mean_realized_price_usd",
        "mean_realized_price_usd_10y",
        "mean_realized_price_usd_5y",
        "mean_realized_price_usd_3y",
        "mean_realized_price_usd_2y",
        "mean_realized_price_usd_365d",
        "mean_realized_price_usd_180d",
        "mean_realized_price_usd_90d",
        "mean_realized_price_usd_60d",
        "mean_realized_price_usd_30d",
        "mean_realized_price_usd_7d",
        "mean_realized_price_usd_1d",
        # mvrv Metrics
        "mvrv_long_short_diff_usd",
        "mvrv_usd",
        "mvrv_usd_10y",
        "mvrv_usd_5y",
        "mvrv_usd_3y",
        "mvrv_usd_2y",
        "mvrv_usd_365d",
        "mvrv_usd_180d",
        "mvrv_usd_90d",
        "mvrv_usd_60d",
        "mvrv_usd_30d",
        "mvrv_usd_7d",
        "mvrv_usd_1d",
        "mvrv_usd_intraday",
        "mvrv_usd_intraday_10y",
        "mvrv_usd_intraday_5y",
        "mvrv_usd_intraday_3y",
        "mvrv_usd_intraday_2y",
        "mvrv_usd_intraday_365d",
        "mvrv_usd_intraday_180d",
        "mvrv_usd_intraday_90d",
        "mvrv_usd_intraday_60d",
        "mvrv_usd_intraday_30d",
        "mvrv_usd_intraday_7d",
        "mvrv_usd_intraday_1d",
        # circulation metrics
        "circulation_10y",
        "circulation_5y",
        "circulation_3y",
        "circulation_2y",
        "circulation_365d",
        "circulation_180d",
        "circulation_90d",
        "circulation_60d",
        "circulation_30d",
        "circulation_7d",
        "circulation_1d",
        "circulation_usd_180d",
        # dormant ciruclation
        "dormant_circulation_10y",
        "dormant_circulation_5y",
        "dormant_circulation_3y",
        "dormant_circulation_2y",
        "dormant_circulation_365d",
        "dormant_circulation_180d",
        "dormant_circulation_90d",
        "dormant_circulation_usd_180d",
        # other
        "mean_age",
        "mean_dollar_invested_age",
        "realized_value_usd",
        "realized_value_usd_10y",
        "realized_value_usd_5y",
        "realized_value_usd_3y",
        "realized_value_usd_2y",
        "realized_value_usd_365d",
        "realized_value_usd_180d",
        "realized_value_usd_90d",
        "realized_value_usd_60d",
        "realized_value_usd_30d",
        "realized_value_usd_7d",
        "realized_value_usd_1d",
        "velocity",
        "transaction_volume",
        "transaction_volume_usd",
        "exchange_inflow",
        "exchange_inflow_v2",
        "exchange_outflow",
        "exchange_outflow_v2",
        "exchange_balance",
        "exchange_balance_v2",
        "exchange_inflow_usd",
        "exchange_outflow_usd",
        "age_consumed",
        "age_destroyed",
        "nvt",
        "nvt_transaction_volume",
        "nvt_5min",
        "network_growth",
        "active_deposits",
        "deposit_transactions",
        "active_withdrawals",
        "withdrawal_transactions",
        "active_deposits_5m",
        "deposit_transactions_5m",
        "active_withdrawals_5m",
        "withdrawal_transactions_5m",
        "payments_count",
        "transactions_count",
        "fees",
        "fees_usd",
        "fees_intraday",
        "fees_usd_intraday",
        "average_fees_usd",
        "median_fees_usd",
        "average_fees_usd_5m",
        "median_fees_usd_5m",
        "network_circulation_usd_1d",
        "fees_to_network_circulation_usd_1d",
        "avg_gas_used",
        "network_profit_loss",
        "total_supply_in_profit",
        "percent_of_total_supply_in_profit",
        "average_transfer_5m",
        "median_transfer_5m",
        "whale_transaction_count_100k_usd_to_inf",
        "whale_transaction_count_1m_usd_to_inf",
        "mvrv_usd_z_score",
        "stock_to_flow",
        "miners_total_supply",
        "percent_of_whale_stablecoin_total_supply",
        # social metrics
        "community_messages_count_telegram",
        "community_messages_count_total",
        "social_dominance_reddit",
        "social_dominance_telegram",
        "social_dominance_bitcointalk",
        "social_dominance_twitter",
        "social_dominance_total",
        "social_dominance_total_1h_moving_average",
        "social_dominance_total_24h_moving_average",
        "social_dominance_telegram_1h_moving_average",
        "social_dominance_telegram_24h_moving_average",
        "social_dominance_reddit_1h_moving_average",
        "social_dominance_reddit_24h_moving_average",
        "social_dominance_twitter_1h_moving_average",
        "social_dominance_twitter_24h_moving_average",
        "social_dominance_bitcointalk_1h_moving_average",
        "social_dominance_bitcointalk_24h_moving_average",
        "social_volume_reddit",
        "social_volume_twitter",
        "social_volume_bitcointalk",
        "social_volume_telegram",
        "social_volume_total",
        "unique_social_volume_total_5m",
        "unique_social_volume_total_1h",
        "sentiment_positive_telegram",
        "sentiment_positive_reddit",
        "sentiment_positive_twitter",
        "sentiment_positive_bitcointalk",
        "sentiment_positive_total",
        "sentiment_negative_telegram",
        "sentiment_negative_reddit",
        "sentiment_negative_twitter",
        "sentiment_negative_bitcointalk",
        "sentiment_negative_total",
        "sentiment_balance_telegram",
        "sentiment_balance_reddit",
        "sentiment_balance_twitter",
        "sentiment_balance_bitcointalk",
        "sentiment_balance_total",
        "sentiment_volume_consumed_telegram",
        "sentiment_volume_consumed_reddit",
        "sentiment_volume_consumed_twitter",
        "sentiment_volume_consumed_bitcointalk",
        "sentiment_volume_consumed_total",
        "social_active_users",
        # histogram metrics
        "age_distribution",
        "price_histogram",
        "spent_coins_cost",
        "all_spent_coins_cost",
        "uniswap_top_claimers",
        # exchange supply metrics
        "supply_on_exchanges",
        "supply_on_exchanges_v2",
        "supply_outside_exchanges",
        "percent_of_total_supply_on_exchanges",
        # top holders metrics
        "amount_in_top_holders",
        "amount_in_exchange_top_holders",
        "amount_in_non_exchange_top_holders",
        # holders distribution metrics
        "holders_distribution_0.001_to_0.01",
        "holders_distribution_0.01_to_0.1",
        "holders_distribution_0.1_to_1",
        "holders_distribution_0_to_0.001",
        "holders_distribution_100_to_1k",
        "holders_distribution_100k_to_1M",
        "holders_distribution_10M_to_inf",
        "holders_distribution_10_to_100",
        "holders_distribution_10k_to_100k",
        "holders_distribution_1M_to_10M",
        "holders_distribution_1_to_10",
        "holders_distribution_1k_to_10k",
        "holders_distribution_combined_balance_0.001_to_0.01",
        "holders_distribution_combined_balance_0.01_to_0.1",
        "holders_distribution_combined_balance_0.1_to_1",
        "holders_distribution_combined_balance_0_to_0.001",
        "holders_distribution_combined_balance_100_to_1k",
        "holders_distribution_combined_balance_100k_to_1M",
        "holders_distribution_combined_balance_10M_to_inf",
        "holders_distribution_combined_balance_10_to_100",
        "holders_distribution_combined_balance_10k_to_100k",
        "holders_distribution_combined_balance_1M_to_10M",
        "holders_distribution_combined_balance_1_to_10",
        "holders_distribution_combined_balance_1k_to_10k",
        "holders_distribution_combined_balance_total",
        "holders_distribution_total",
        "holders_distribution_over_1",
        "holders_distribution_over_10",
        "holders_distribution_over_100",
        "holders_distribution_over_1k",
        "holders_distribution_over_10k",
        "holders_distribution_over_100k",
        "holders_distribution_over_1M",
        "holders_distribution_combined_balance_over_1",
        "holders_distribution_combined_balance_over_10",
        "holders_distribution_combined_balance_over_100",
        "holders_distribution_combined_balance_over_1k",
        "holders_distribution_combined_balance_over_10k",
        "holders_distribution_combined_balance_over_100k",
        "holders_distribution_combined_balance_over_1M",
        "percent_of_holders_distribution_combined_balance_0_to_0.001",
        "percent_of_holders_distribution_combined_balance_0.001_to_0.01",
        "percent_of_holders_distribution_combined_balance_0.01_to_0.1",
        "percent_of_holders_distribution_combined_balance_0.1_to_1",
        "percent_of_holders_distribution_combined_balance_1_to_10",
        "percent_of_holders_distribution_combined_balance_10_to_100",
        "percent_of_holders_distribution_combined_balance_100_to_1k",
        "percent_of_holders_distribution_combined_balance_1k_to_10k",
        "percent_of_holders_distribution_combined_balance_10k_to_100k",
        "percent_of_holders_distribution_combined_balance_100k_to_1M",
        "percent_of_holders_distribution_combined_balance_1M_to_10M",
        "percent_of_holders_distribution_combined_balance_10M_to_inf",
        "percent_of_holders_distribution_0_to_0.001",
        "percent_of_holders_distribution_0.001_to_0.01",
        "percent_of_holders_distribution_0.01_to_0.1",
        "percent_of_holders_distribution_0.1_to_1",
        "percent_of_holders_distribution_1_to_10",
        "percent_of_holders_distribution_10_to_100",
        "percent_of_holders_distribution_100_to_1k",
        "percent_of_holders_distribution_1k_to_10k",
        "percent_of_holders_distribution_10k_to_100k",
        "percent_of_holders_distribution_100k_to_1M",
        "percent_of_holders_distribution_1M_to_10M",
        "percent_of_holders_distribution_10M_to_inf",
        # makerdao metrics
        "dai_created",
        "dai_repaid",
        "mcd_liquidation",
        "mcd_collat_ratio",
        "mcd_collat_ratio_sai",
        "mcd_collat_ratio_weth",
        "mcd_dsr",
        "mcd_locked_token",
        "mcd_stability_fee",
        "mcd_supply",
        "scd_collat_ratio",
        "scd_locked_token",
        # derivatives
        "bitmex_perpetual_funding_rate",
        "bitmex_perpetual_basis",
        "bitmex_perpetual_open_interest",
        "bitmex_perpetual_open_value",
        "bitmex_perpetual_basis_ratio",
        "bitmex_perpetual_price",
        "bitmex_composite_price_index",
        # label metrics
        "active_deposits_per_exchange",
        "active_withdrawals_per_exchange",
        "deposit_transactions_per_exchange",
        "exchange_inflow_per_exchange",
        "exchange_outflow_per_exchange",
        "inflow_per_label_and_owner",
        "outflow_per_label_and_owner",
        "exchange_balance_per_exchange",
        "balance_per_label_and_owner_delta",
        "balance_per_owner",
        "exchange_balance_per_exchange",
        "withdrawal_transactions_per_exchange",
        "total_trade_volume_by_dex",
        "eth_based_trade_volume_by_dex",
        "stablecoin_trade_volume_by_dex",
        "other_trade_volume_by_dex",
        "total_trade_amount_by_dex",
        "eth_based_trade_amount_by_dex",
        "stablecoin_trade_amount_by_dex",
        "other_trade_amount_by_dex",
        "eth_trade_volume_by_token",
        "stablecoin_trade_volume_by_token",
        "token_eth_price_by_dex_5m",
        "nft_trades_count",
        "nft_trade_volume_usd",
        "nft_whale_trades_count",
        "nft_whale_trade_volume_usd",
        "nft_retail_trades_count",
        "nft_retail_trade_volume_usd",
        # label balances
        "labelled_historical_balance",
        "labelled_historical_balance_changes",
        # table metrics
        "labelled_exchange_balance_sum",
        # balance and flow labeled metrics
        "miners_balance",
        "genesis_balance",
        "dex_trader_balance",
        "trader_balance",
        "defi_balance",
        "dex_balance",
        "cex_balance",
        "withdrawal_balance",
        "deposit_balance",
        "proxy_balance",
        "whale_balance",
        "makerdao_bite_keeper_balance",
        "makerdao_cdp_owner_balance",
        "proxy_balance",
        "miners_to_exchanges_flow",
        "exchanges_to_miners_flow",
        "miners_exchange_balance",
        "whales_to_exchanges_flow",
        "exchanges_to_whales_flow",
        "whales_exchange_balance",
        "traders_to_exchanges_flow",
        "exchanges_to_traders_flow",
        "traders_exchange_balance",
        "traders_to_dexes_flow",
        "dexes_to_traders_flow",
        "traders_dex_balance",
        "traders_to_cexes_flow",
        "cexes_to_traders_flow",
        "traders_cex_balance",
        "traders_to_defi_flow",
        "defi_to_traders_flow",
        "traders_defi_balance",
        "dex_traders_to_exchanges_flow",
        "exchanges_to_dex_traders_flow",
        "dex_traders_exchange_balance",
        "defi_to_exchanges_flow",
        "exchanges_to_defi_flow",
        "defi_exchange_balance",
        "dex_traders_to_dexes_flow",
        "dexes_to_dex_traders_flow",
        "dex_traders_dex_balance",
        "dex_traders_to_cexes_flow",
        "cexes_to_dex_traders_flow",
        "dex_traders_cex_balance",
        "dex_traders_to_defi_flow",
        "defi_to_dex_traders_flow",
        "dex_traders_defi_balance",
        "genesis_to_exchanges_flow",
        "exchanges_to_genesis_flow",
        "genesis_exchange_balance",
        "other_to_exchanges_flow",
        "exchanges_to_other_flow",
        "other_exchange_balance",
        "unlabeled_to_labeled_flow",
        "labeled_to_unlabeled_flow",
        "unlabeled_to_unlabeled_flow",
        "labeled_to_labeled_flow",
        "unlabeled_balance",
        "all_known_balance",
        "defi_to_cexes_flow",
        "cexes_to_defi_flow",
        "defi_cex_balance",
        "whale_to_cexes_flow",
        "cexes_to_whale_flow",
        "whale_cex_balance",
        "dex_to_cexes_flow",
        "cexes_to_dex_flow",
        "dex_cex_balance",
        "other_to_cexes_flow",
        "cexes_to_other_flow",
        "other_cex_balance",
        "defi_to_dexes_flow",
        "dexes_to_defi_flow",
        "defi_dex_balance",
        "whale_to_dexes_flow",
        "dexes_to_whale_flow",
        "whale_dex_balance",
        "other_to_dexes_flow",
        "dexes_to_other_flow",
        "other_dex_balance",
        "whale_to_defi_flow",
        "defi_to_whale_flow",
        "whale_defi_balance",
        "other_to_defi_flow",
        "defi_to_other_flow",
        "other_defi_balance",
        "dex_traders_to_whale_flow",
        "whale_to_dex_traders_flow",
        "dex_traders_whale_balance",
        "traders_to_whale_flow",
        "whale_to_traders_flow",
        "traders_whale_balance",
        "other_to_whale_flow",
        "whale_to_other_flow",
        "other_whale_balance",
        "other_to_dex_traders_flow",
        "dex_traders_to_other_flow",
        "other_dex_traders_balance",
        "other_to_traders_flow",
        "traders_to_other_flow",
        "other_traders_balance",
        # labeled holders metrics
        "holders_labeled_negative_distribution_100_to_1k",
        "holders_labeled_negative_distribution_0.1_to_1",
        "holders_labeled_distribution_combined_balance_total",
        "holders_labeled_distribution_combined_balance_0_to_0.001",
        "holders_labeled_negative_distribution_combined_balance_0.01_to_0.1",
        "holders_labeled_negative_distribution_combined_balance_total",
        "holders_labeled_distribution_combined_balance_100k_to_1M",
        "holders_labeled_negative_distribution_0.001_to_0.01",
        "holders_labeled_distribution_combined_balance_0.01_to_0.1",
        "holders_labeled_negative_distribution_1k_to_10k",
        "holders_labeled_distribution_combined_balance_100_to_1k",
        "holders_labeled_distribution_100_to_1k",
        "holders_labeled_distribution_0.1_to_1",
        "holders_labeled_negative_distribution_combined_balance_1M_to_10M",
        "holders_labeled_negative_distribution_combined_balance_0.001_to_0.01",
        "holders_labeled_negative_distribution_10_to_100",
        "holders_labeled_distribution_combined_balance_10_to_100",
        "holders_labeled_distribution_10_to_100",
        "holders_labeled_distribution_10M_to_inf",
        "holders_labeled_negative_distribution_10k_to_100k",
        "holders_labeled_distribution_10k_to_100k",
        "holders_labeled_distribution_0.001_to_0.01",
        "holders_labeled_distribution_0.01_to_0.1",
        "holders_labeled_negative_distribution_combined_balance_10_to_100",
        "holders_labeled_distribution_combined_balance_10k_to_100k",
        "holders_labeled_distribution_combined_balance_0.1_to_1",
        "holders_labeled_negative_distribution_combined_balance_100k_to_1M",
        "holders_labeled_distribution_combined_balance_1_to_10",
        "holders_labeled_distribution_combined_balance_1k_to_10k",
        "holders_labeled_negative_distribution_1M_to_10M",
        "holders_labeled_negative_distribution_combined_balance_100_to_1k",
        "holders_labeled_negative_distribution_combined_balance_1_to_10",
        "holders_labeled_negative_distribution_combined_balance_0.1_to_1",
        "holders_labeled_distribution_1M_to_10M",
        "holders_labeled_negative_distribution_1_to_10",
        "holders_labeled_negative_distribution_0.01_to_0.1",
        "holders_labeled_distribution_combined_balance_1M_to_10M",
        "holders_labeled_distribution_combined_balance_0.001_to_0.01",
        "holders_labeled_distribution_0_to_0.001",
        "holders_labeled_distribution_1k_to_10k",
        "holders_labeled_distribution_100k_to_1M",
        "holders_labeled_negative_distribution_combined_balance_0_to_0.001",
        "holders_labeled_negative_distribution_combined_balance_10k_to_100k",
        "holders_labeled_negative_distribution_combined_balance_1k_to_10k",
        "holders_labeled_negative_distribution_10M_to_inf",
        "holders_labeled_distribution_total",
        "holders_labeled_distribution_1_to_10",
        "holders_labeled_negative_distribution_total",
        "holders_labeled_negative_distribution_combined_balance_10M_to_inf",
        "holders_labeled_negative_distribution_100k_to_1M",
        "holders_labeled_negative_distribution_0_to_0.001",
        "holders_labeled_distribution_combined_balance_10M_to_inf",
        # ETH2 metrics
        "eth2_stakers_count",
        "eth2_roi",
        # Defi
        "defi_total_value_locked_eth",
        "defi_total_value_locked_usd",
        # Change metrics
        "age_destroyed_change_1d",
        "age_destroyed_change_30d",
        "age_destroyed_change_7d",
        "network_growth_change_1d",
        "network_growth_change_7d",
        "network_growth_change_30d",
        "exchange_inflow_change_1d",
        "exchange_inflow_change_7d",
        "exchange_inflow_change_30d",
        "exchange_outflow_change_1d",
        "exchange_outflow_change_7d",
        "exchange_outflow_change_30d",
        "exchange_balance_change_1d",
        "exchange_balance_change_7d",
        "exchange_balance_change_30d",
        "transaction_volume_change_1d",
        "transaction_volume_change_7d",
        "transaction_volume_change_30d",
        "transaction_volume_usd_change_1d",
        "transaction_volume_usd_change_7d",
        "transaction_volume_usd_change_30d",
        "dormant_circulation_365d_change_1d",
        "dormant_circulation_365d_change_7d",
        "dormant_circulation_365d_change_30d",
        "circulation_180d_change_1d",
        "circulation_180d_change_7d",
        "circulation_180d_change_30d",
        "circulation_change_1d",
        "circulation_change_7d",
        "circulation_change_30d",
        "bitmex_perpetual_funding_rate_change_1d",
        "bitmex_perpetual_funding_rate_change_7d",
        "bitmex_perpetual_funding_rate_change_30d",
        "mvrv_usd_30d_change_1d",
        "mvrv_usd_30d_change_7d",
        "mvrv_usd_30d_change_30d",
        "mvrv_usd_180d_change_1d",
        "mvrv_usd_180d_change_7d",
        "mvrv_usd_180d_change_30d",
        "mvrv_usd_365d_change_1d",
        "mvrv_usd_365d_change_7d",
        "mvrv_usd_365d_change_30d",
        "mvrv_usd_change_1d",
        "mvrv_usd_change_7d",
        "mvrv_usd_change_30d",
        "mean_dollar_invested_age_change_1d",
        "mean_dollar_invested_age_change_7d",
        "mean_dollar_invested_age_change_30d",
        "percent_of_total_supply_on_exchanges_change_1d",
        "percent_of_total_supply_on_exchanges_change_7d",
        "percent_of_total_supply_on_exchanges_change_30d",
        "circulation_usd_180d_change_1d",
        "circulation_usd_180d_change_7d",
        "circulation_usd_180d_change_30d",
        "dormant_circulation_usd_180d_change_1d",
        "dormant_circulation_usd_180d_change_7d",
        "dormant_circulation_usd_180d_change_30d",
        "exchange_inflow_usd_change_1d",
        "exchange_inflow_usd_change_7d",
        "exchange_inflow_usd_change_30d",
        "exchange_outflow_usd_change_1d",
        "exchange_outflow_usd_change_7d",
        "exchange_outflow_usd_change_30d",
        "price_daa_divergence",
        "adjusted_price_daa_divergence",
        "social_volume_total_change_1d",
        "social_volume_total_change_7d",
        "social_volume_total_change_30d",
        "sentiment_balance_total_change_1d",
        "sentiment_balance_total_change_7d",
        "sentiment_balance_total_change_30d",
        "social_dominance_total_change_1d",
        "social_dominance_total_change_7d",
        "social_dominance_total_change_30d",
        "social_dominance_total_1h_moving_average_change_1d",
        "social_dominance_total_1h_moving_average_change_7d",
        "social_dominance_total_1h_moving_average_change_30d",
        "social_dominance_total_24h_moving_average_change_1d",
        "social_dominance_total_24h_moving_average_change_7d",
        "social_dominance_total_24h_moving_average_change_30d",
        "dex_traders_to_dexes_flow_change_1d",
        "dex_traders_to_dexes_flow_change_7d",
        "dex_traders_to_dexes_flow_change_30d",
        "dex_traders_to_cexes_flow_change_1d",
        "dex_traders_to_cexes_flow_change_7d",
        "dex_traders_to_cexes_flow_change_30d",
        "dex_traders_to_defi_flow_change_1d",
        "dex_traders_to_defi_flow_change_7d",
        "dex_traders_to_defi_flow_change_30d",
        "dex_traders_to_whale_flow_change_1d",
        "dex_traders_to_whale_flow_change_7d",
        "dex_traders_to_whale_flow_change_30d",
        "dex_traders_to_other_flow_change_1d",
        "dex_traders_to_other_flow_change_7d",
        "dex_traders_to_other_flow_change_30d",
        "dexes_to_dex_traders_flow_change_1d",
        "dexes_to_dex_traders_flow_change_7d",
        "dexes_to_dex_traders_flow_change_30d",
        "dex_to_cexes_flow_change_1d",
        "dex_to_cexes_flow_change_7d",
        "dex_to_cexes_flow_change_30d",
        "dexes_to_defi_flow_change_1d",
        "dexes_to_defi_flow_change_7d",
        "dexes_to_defi_flow_change_30d",
        "dexes_to_whale_flow_change_1d",
        "dexes_to_whale_flow_change_7d",
        "dexes_to_whale_flow_change_30d",
        "dexes_to_other_flow_change_1d",
        "dexes_to_other_flow_change_7d",
        "dexes_to_other_flow_change_30d",
        "cexes_to_dex_traders_flow_change_1d",
        "cexes_to_dex_traders_flow_change_7d",
        "cexes_to_dex_traders_flow_change_30d",
        "cexes_to_dex_flow_change_1d",
        "cexes_to_dex_flow_change_7d",
        "cexes_to_dex_flow_change_30d",
        "cexes_to_defi_flow_change_1d",
        "cexes_to_defi_flow_change_7d",
        "cexes_to_defi_flow_change_30d",
        "cexes_to_whale_flow_change_1d",
        "cexes_to_whale_flow_change_7d",
        "cexes_to_whale_flow_change_30d",
        "cexes_to_other_flow_change_1d",
        "cexes_to_other_flow_change_7d",
        "cexes_to_other_flow_change_30d",
        "defi_to_dex_traders_flow_change_1d",
        "defi_to_dex_traders_flow_change_7d",
        "defi_to_dex_traders_flow_change_30d",
        "defi_to_dexes_flow_change_1d",
        "defi_to_dexes_flow_change_7d",
        "defi_to_dexes_flow_change_30d",
        "defi_to_cexes_flow_change_1d",
        "defi_to_cexes_flow_change_7d",
        "defi_to_cexes_flow_change_30d",
        "defi_to_whale_flow_change_1d",
        "defi_to_whale_flow_change_7d",
        "defi_to_whale_flow_change_30d",
        "defi_to_other_flow_change_1d",
        "defi_to_other_flow_change_7d",
        "defi_to_other_flow_change_30d",
        "whale_to_dex_traders_flow_change_1d",
        "whale_to_dex_traders_flow_change_7d",
        "whale_to_dex_traders_flow_change_30d",
        "whale_to_dexes_flow_change_1d",
        "whale_to_dexes_flow_change_7d",
        "whale_to_dexes_flow_change_30d",
        "whale_to_cexes_flow_change_1d",
        "whale_to_cexes_flow_change_7d",
        "whale_to_cexes_flow_change_30d",
        "whale_to_defi_flow_change_1d",
        "whale_to_defi_flow_change_7d",
        "whale_to_defi_flow_change_30d",
        "whale_to_other_flow_change_1d",
        "whale_to_other_flow_change_7d",
        "whale_to_other_flow_change_30d",
        "other_to_dex_traders_flow_change_1d",
        "other_to_dex_traders_flow_change_7d",
        "other_to_dex_traders_flow_change_30d",
        "other_to_dexes_flow_change_1d",
        "other_to_dexes_flow_change_7d",
        "other_to_dexes_flow_change_30d",
        "other_to_cexes_flow_change_1d",
        "other_to_cexes_flow_change_7d",
        "other_to_cexes_flow_change_30d",
        "other_to_defi_flow_change_1d",
        "other_to_defi_flow_change_7d",
        "other_to_defi_flow_change_30d",
        "other_to_whale_flow_change_1d",
        "other_to_whale_flow_change_7d",
        "other_to_whale_flow_change_30d",
        "traders_to_other_flow_change_1d",
        "traders_to_other_flow_change_7d",
        "traders_to_other_flow_change_30d",
        "other_to_traders_flow_change_1d",
        "other_to_traders_flow_change_7d",
        "other_to_traders_flow_change_30d",
        "whale_to_traders_flow_change_1d",
        "whale_to_traders_flow_change_7d",
        "whale_to_traders_flow_change_30d",
        "traders_to_whale_flow_change_1d",
        "traders_to_whale_flow_change_7d",
        "traders_to_whale_flow_change_30d",
        "social_dominance_total_change_1d",
        "social_dominance_total_change_7d",
        "social_dominance_total_change_30d",
        "sentiment_balance_total_change_1d",
        "sentiment_balance_total_change_7d",
        "sentiment_balance_total_change_30d",
        "network_profit_loss_change_1d",
        "network_profit_loss_change_7d",
        "network_profit_loss_change_30d",
        "whale_transaction_count_100k_usd_to_inf_change_1d",
        "whale_transaction_count_100k_usd_to_inf_change_7d",
        "whale_transaction_count_100k_usd_to_inf_change_30d",
        "whale_transaction_count_1m_usd_to_inf_change_1d",
        "whale_transaction_count_1m_usd_to_inf_change_7d",
        "whale_transaction_count_1m_usd_to_inf_change_30d",
        # bnb funding rates metrics
        "usdt_bnb_funding_rates",
        "usdt_binance_funding_rate",
        "busd_bnb_funding_rates",
        "busd_binance_funding_rate",
        # ftx funding rates metric
        "ftx_perpetual_funding_rate",
        # bitfinex funding rates metric
        "bitfinex_perpetual_funding_rate",
        # dydx funding rates metric
        "dydx_perpetual_funding_rate",
        # deribit funding rates metric
        "deribit_perpetual_funding_rate",
        "sentiment_volume_consumed_total_change_1d",
        "sentiment_volume_consumed_total_change_7d",
        "sentiment_volume_consumed_total_change_30d"
      ]
      |> Enum.sort()

    # The diff algorithm fails to nicely print that a single metric is
    # missing but instead shows some not-understandable result when comparing
    # the lists directly

    # not present in expected
    assert MapSet.difference(
             MapSet.new(restricted_metrics),
             MapSet.new(expected_restricted_metrics)
           )
           |> Enum.to_list() == []

    # not present in the metrics list
    assert MapSet.difference(
             MapSet.new(expected_restricted_metrics),
             MapSet.new(restricted_metrics)
           )
           |> Enum.to_list() == []
  end

  test "extension needed metrics", %{metrics_access_map: access_map} do
    # Forbidden queries are acessible only by basic authorization
    extension_metrics =
      Sanbase.Billing.GraphqlSchema.get_with_access_level(access_map, :extension)
      |> Enum.sort()

    assert extension_metrics == []
  end

  test "forbidden metrics", %{metrics_access_map: access_map} do
    forbidden_metrics =
      Sanbase.Billing.GraphqlSchema.get_with_access_level(access_map, :forbidden)
      |> Enum.sort()

    expected_forbidden_metrics =
      []
      |> Enum.sort()

    assert forbidden_metrics == expected_forbidden_metrics
  end

  test "metrics with free realtime and restricted historical data", %{
    metrics_access_map: access_map
  } do
    result =
      access_map
      |> Enum.filter(&match?({_, %{"historical" => :restricted, "realtime" => :free}}, &1))
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    expected =
      [
        "social_volume_bitcointalk",
        "social_volume_reddit",
        "social_volume_telegram",
        "social_volume_total",
        "social_volume_twitter"
      ]
      |> Enum.sort()

    assert result == expected
  end

  test "metrics with restricted realtime and free historical data", %{
    metrics_access_map: access_map
  } do
    result =
      access_map
      |> Enum.filter(&match?({_, %{"historical" => :free, "realtime" => :restricted}}, &1))
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    assert result == []
  end
end
