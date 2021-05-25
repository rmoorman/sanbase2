import Config

config :sanbase, Sanbase.StripeConfig, api_key: {:system, "STRIPE_SECRET_KEY", ""}

config :stripity_stripe,
  api_key: {Sanbase.StripeConfig, :api_key, []},
  json_library: Jason

config :sanbase, SanbaseWeb.Plug.VerifyStripeWebhook,
  webhook_secret: {:system, "STRIPE_WEBHOOK_SECRET", ""}

config :sanbase, Sanbase.Billing.DiscordNotification,
  webhook_url: {:system, "STRIPE_PAYMENT_DISCORD_WEBHOOK"},
  publish_user: {:system, "STRIPE_PAYMENT_DISCORD_PUBLISH_USER", "Stripe Payments Bot"}
