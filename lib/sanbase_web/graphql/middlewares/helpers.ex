defmodule SanbaseWeb.Graphql.Middlewares.Helpers do
  @moduledoc ~s"""
  Common functions used among multiple middlewares
  """

  alias __MODULE__
  alias Sanbase.Accounts.User
  alias Absinthe.Resolution

  def has_enough_san_tokens?(_, 0), do: true

  def has_enough_san_tokens?(san_tokens, required_san_tokens) do
    if san_tokens >= required_san_tokens do
      true
    else
      {:error, "Insufficient SAN balance"}
    end
  end

  def allow_access?(_current_user, true), do: true

  def allow_access?(%User{privacy_policy_accepted: privacy_policy_accepted}, allow_access) do
    if allow_access || privacy_policy_accepted do
      true
    else
      {:error, "Access denied. Accept the privacy policy to activate your account."}
    end
  end

  def handle_user_access(current_user, san_tokens, opts, resolution) do
    required_san_tokens = Keyword.get(opts, :san_tokens, 0) |> Sanbase.Math.to_float()
    allow_access = Keyword.get(opts, :allow_access, false)

    with true <- Helpers.allow_access?(current_user, allow_access),
         true <- Helpers.has_enough_san_tokens?(san_tokens, required_san_tokens) do
      resolution
    else
      {:error, _message} = error ->
        resolution
        |> Resolution.put_result(error)
    end
  end
end
