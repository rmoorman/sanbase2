defmodule Sanbase.Billing.Subscription do
  @moduledoc """
  Module for managing user subscriptions - create, upgrade/downgrade, cancel.
  Also containing some helper functions that take user subscription as argument and
  return some properties of the subscription plan.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Sanbase.Billing
  alias Sanbase.Billing.{Plan, Product}
  alias Sanbase.Billing.Subscription.{SignUpTrial, Query}

  alias Sanbase.Accounts.User
  alias Sanbase.Repo
  alias Sanbase.StripeApi

  require Logger

  @percent_discount_1000_san 20
  @generic_error_message """
  Current subscription attempt failed.
  Please, contact administrator of the site for more information.
  """
  @product_sanbase Product.product_sanbase()
  @sanbase_basic_plan_id 205
  @preload_fields [:user, plan: [:product]]

  schema "subscriptions" do
    field(:stripe_id, :string)
    field(:current_period_end, :utc_datetime)
    field(:cancel_at_period_end, :boolean, null: false, default: false)
    field(:status, SubscriptionStatusEnum)
    field(:trial_end, :utc_datetime)

    belongs_to(:user, User)
    belongs_to(:plan, Plan)

    timestamps()
  end

  def generic_error_message, do: @generic_error_message

  def changeset(%__MODULE__{} = subscription, attrs \\ %{}) do
    subscription
    |> cast(attrs, [
      :plan_id,
      :user_id,
      :stripe_id,
      :current_period_end,
      :trial_end,
      :cancel_at_period_end,
      :status,
      :inserted_at
    ])
    |> foreign_key_constraint(:plan_id, name: :subscriptions_plan_id_fkey)
  end

  def create(params) do
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end

  def by_id(id) do
    Repo.get(__MODULE__, id) |> default_preload()
  end

  @spec by_stripe_id(String.t()) :: %__MODULE__{} | nil
  def by_stripe_id(stripe_id) do
    Repo.get_by(__MODULE__, stripe_id: stripe_id) |> default_preload()
  end

  @spec free_subscription() :: %__MODULE__{}
  def free_subscription() do
    %__MODULE__{plan: Plan.free_plan()}
  end

  def create_subscription_db(stripe_subscription, user, plan) do
    %__MODULE__{}
    |> changeset(%{
      stripe_id: stripe_subscription.id,
      user_id: user.id,
      plan_id: plan.id,
      current_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
      cancel_at_period_end: stripe_subscription.cancel_at_period_end,
      status: stripe_subscription.status,
      trial_end: format_trial_end(stripe_subscription.trial_end),
      inserted_at: DateTime.from_unix!(stripe_subscription.created) |> DateTime.to_naive()
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  def update_subscription_db(subscription, params) do
    subscription
    |> changeset(params)
    |> Repo.update()
  end

  def sync_stripe_subscriptions() do
    __MODULE__
    |> Repo.all()
    |> Enum.each(&sync_subscription_with_stripe/1)
  end

  @doc """
  Subscribe user with card_token to a plan.

  - Create or update a Stripe customer with card details contained by the card_token param.
  - Create subscription record in Stripe.
  - Create a subscription record locally so we can check access control without calling Stripe.
  """
  @type string_or_nil :: String.t() | nil
  @spec subscribe(%User{}, %Plan{}, string_or_nil, string_or_nil) ::
          {:ok, %__MODULE__{}} | {:error, %Stripe.Error{} | String.t()}
  def subscribe(user, plan, card_token \\ nil, coupon \\ nil) do
    with :ok <- active_subscriptions_for_this_plan(user, plan),
         {:ok, user} <- Billing.create_or_update_stripe_customer(user, card_token),
         {:ok, stripe_subscription} <- create_stripe_subscription(user, plan, coupon),
         {:ok, db_subscription} <- create_subscription_db(stripe_subscription, user, plan),
         {:ok, _} <- Sanbase.ApiCallLimit.update_user_plan(user) do
      # Remove sign up trial if exists.
      plan.product_id == @product_sanbase && SignUpTrial.remove_sign_up_trial(user)

      {:ok, default_preload(db_subscription, force: true)}
    end
  end

  @doc """
  Upgrade or Downgrade plan:
  - Updates subcription in Stripe with new plan.
  - Updates local subscription
  Stripe docs: https://stripe.com/docs/billing/subscriptions/upgrading-downgrading#switching
  """
  def update_subscription(%__MODULE__{} = db_subscription, plan) do
    with {:ok, stripe_subscription} <-
           StripeApi.update_subscription_item_by_id(db_subscription, plan),
         {:ok, db_subscription} <-
           sync_subscription_with_stripe(stripe_subscription, db_subscription),
         db_subscription <- default_preload(db_subscription, force: true),
         {:ok, _} <- Sanbase.ApiCallLimit.update_user_plan(db_subscription.user) do
      {:ok, db_subscription}
    end
  end

  @doc """
  Cancel subscription.
  Cancellation means scheduling for cancellation at the end of the billing cycle.
  It updates the `cancel_at_period_end` field which will cancel the subscription
  at `current_period_end` future time. That allows user to use the subscription for the time
  left that he has already paid for.
  https://stripe.com/docs/billing/subscriptions/canceling-pausing#canceling
  """
  def cancel_subscription(%__MODULE__{stripe_id: stripe_id} = db_subscription)
      when is_binary(stripe_id) do
    with {:ok, stripe_subscription} <- StripeApi.cancel_subscription(stripe_id),
         {:ok, _canceled_sub} <-
           sync_subscription_with_stripe(stripe_subscription, db_subscription),
         db_subscription <- default_preload(db_subscription, force: true),
         {:ok, _} <- Sanbase.ApiCallLimit.update_user_plan(db_subscription.user) do
      Sanbase.Billing.StripeEvent.send_cancel_event_to_discord(db_subscription)

      {:ok,
       %{
         is_scheduled_for_cancellation: true,
         scheduled_for_cancellation_at: db_subscription.current_period_end
       }}
    end
  end

  def cancel_subscription(_),
    do: {:error, "This type of automatically created subscription can't be cancelled"}

  @doc """
  Renew cancelled subscription if `current_period_end` is not reached.

  https://stripe.com/docs/billing/subscriptions/canceling-pausing#reactivating-canceled-subscriptions
  """
  def renew_cancelled_subscription(%__MODULE__{} = db_subscription) do
    dt_comparison = DateTime.compare(Timex.now(), db_subscription.current_period_end)

    with {_, :lt} <- {:end_period_reached?, dt_comparison},
         {:ok, stripe_subscription} <-
           StripeApi.update_subscription(db_subscription.stripe_id, %{cancel_at_period_end: false}),
         {:ok, db_subscription} <-
           sync_subscription_with_stripe(stripe_subscription, db_subscription),
         db_subscription = default_preload(db_subscription, force: true),
         {:ok, _} <- Sanbase.ApiCallLimit.update_user_plan(db_subscription.user) do
      {:ok, db_subscription}
    else
      {:end_period_reached?, _} ->
        {:end_period_reached_error,
         "Cancelled subscription has already reached the end period at #{
           db_subscription.current_period_end
         }"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def sync_subscription_with_stripe(%__MODULE__{stripe_id: stripe_id} = db_subscription)
      when is_binary(stripe_id) do
    with {:ok, stripe_subscription} <- StripeApi.retrieve_subscription(stripe_id),
         plan_id <- fetch_plan_id(db_subscription, stripe_subscription) do
      update_local_subsciption(db_subscription, stripe_subscription, plan_id)
    end
  end

  def sync_subscription_with_stripe(_), do: :ok

  def sync_subscription_with_stripe(stripe_subscription, db_subscription) do
    plan_id = fetch_plan_id(db_subscription, stripe_subscription)
    update_local_subsciption(db_subscription, stripe_subscription, plan_id)
  end

  # Leave first active subscription and remove rest
  def remove_duplicate_subscriptions() do
    __MODULE__.Stats.duplicate_sanbase_subscriptions()
    |> Enum.filter(fn subs ->
      subs |> List.first() |> elem(3) == :active
    end)
    |> Enum.each(fn [_ | rest] ->
      Enum.each(rest, fn {_, stripe_id, _, _, _} ->
        Logger.info("Delete duplicate subscription: #{stripe_id}")
        StripeApi.delete_subscription(stripe_id)
      end)
    end)
  end

  @doc """
  List all active user subscriptions with plans and products.
  """
  def user_subscriptions(%User{id: user_id}) do
    __MODULE__
    |> Query.filter_user(user_id)
    |> Query.all_active_and_trialing_subscriptions()
    |> Query.join_plan_and_product()
    |> Query.order_by()
    |> Repo.all()
  end

  @doc """
  List active subcriptions' product ids
  """
  def user_subscriptions_product_ids(%User{id: user_id}) do
    __MODULE__
    |> Query.filter_user(user_id)
    |> Query.all_active_and_trialing_subscriptions()
    |> Query.select_product_id()
    |> Query.order_by()
    |> Repo.all()
  end

  @doc """
  Current subscription is the last active subscription for a product.
  """
  def current_subscription(%User{id: user_id}, product_id) do
    fetch_current_subscription(user_id, product_id)
  end

  def current_subscription(user_id, product_id) when is_integer(user_id) do
    fetch_current_subscription(user_id, product_id)
  end

  def plan_name(nil), do: :free
  def plan_name(%__MODULE__{plan: plan}), do: plan |> Plan.plan_atom_name()

  # Private functions

  defp active_subscriptions_for_this_plan(user, plan) do
    __MODULE__
    |> Query.all_active_subscriptions_for_plan(plan.id)
    |> Query.filter_user(user.id)
    |> Repo.all()
    |> Enum.empty?()
    |> case do
      false ->
        {
          :error,
          %__MODULE__.Error{
            message: "You are already subscribed to #{Plan.plan_full_name(plan)}"
          }
        }

      true ->
        :ok
    end
  end

  # Add 80% off Sanbase Basic subscription for first month
  defp create_stripe_subscription(user, %Plan{id: plan_id} = plan, _)
       when plan_id == @sanbase_basic_plan_id do
    with {:ok, coupon} <- StripeApi.create_coupon(%{percent_off: 80, duration: "once"}) do
      subscription_defaults(user, plan)
      |> update_subscription_with_coupon(coupon)
      |> StripeApi.create_subscription()
    end
  end

  # When user doesn't provide coupon - check if he has SAN staked
  defp create_stripe_subscription(user, plan, nil) do
    percent_off =
      user
      |> User.san_balance_or_zero()
      |> percent_discount()

    subscription_defaults(user, plan)
    |> update_subscription_with_coupon(percent_off)
    |> case do
      {:ok, subscription} ->
        StripeApi.create_subscription(subscription)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # When user provided a coupon - use it
  defp create_stripe_subscription(user, plan, coupon) when not is_nil(coupon) do
    with {:ok, stripe_coupon} <- StripeApi.retrieve_coupon(coupon) do
      subscription_defaults(user, plan)
      |> update_subscription_with_coupon(stripe_coupon)
      |> StripeApi.create_subscription()
    end
  end

  defp subscription_defaults(user, %Plan{product_id: product_id} = plan)
       when product_id == @product_sanbase do
    defaults = %{
      customer: user.stripe_customer_id,
      items: [%{plan: plan.stripe_id}]
    }

    # Transfer left trial to new subscription
    case SignUpTrial.trial_end_dt(user) do
      trial_end_dt = %NaiveDateTime{} ->
        case NaiveDateTime.compare(NaiveDateTime.utc_now(), trial_end_dt) do
          :lt ->
            trial_end_dt = trial_end_dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
            Map.put(defaults, :trial_end, trial_end_dt)

          _ ->
            defaults
        end

      _ ->
        defaults
    end
  end

  defp subscription_defaults(user, plan) do
    %{
      customer: user.stripe_customer_id,
      items: [%{plan: plan.stripe_id}]
    }
  end

  defp update_subscription_with_coupon(subscription, %Stripe.Coupon{id: coupon_id}) do
    Map.put(subscription, :coupon, coupon_id)
  end

  defp update_subscription_with_coupon(subscription, percent_off) when is_integer(percent_off) do
    with {:ok, coupon} <-
           StripeApi.create_coupon(%{percent_off: percent_off, duration: "forever"}) do
      {:ok, Map.put(subscription, :coupon, coupon.id)}
    end
  end

  defp update_subscription_with_coupon(subscription, nil), do: {:ok, subscription}

  defp percent_discount(balance) when balance >= 1000, do: @percent_discount_1000_san
  defp percent_discount(_), do: nil

  defp fetch_current_subscription(user_id, product_id) do
    __MODULE__
    |> Query.filter_user(user_id)
    |> Query.all_active_and_trialing_subscriptions()
    |> Query.last_subscription_for_product(product_id)
    |> Query.preload(plan: [:product])
    |> Repo.one()
  end

  defp default_preload(subscription, opts \\ []) do
    Repo.preload(subscription, @preload_fields, opts)
  end

  defp update_local_subsciption(db_subscription, stripe_subscription, plan_id) do
    args = %{
      current_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
      cancel_at_period_end: stripe_subscription.cancel_at_period_end,
      status: stripe_subscription.status,
      plan_id: plan_id,
      trial_end: format_trial_end(stripe_subscription.trial_end),
      inserted_at: DateTime.from_unix!(stripe_subscription.created) |> DateTime.to_naive()
    }

    update_subscription_db(db_subscription, args)
  end

  defp fetch_plan_id(db_subscription, stripe_subscription) do
    case Plan.by_stripe_id(stripe_subscription.plan.id) do
      %Plan{id: plan_id} -> plan_id
      nil -> db_subscription.plan_id
    end
  end

  defp format_trial_end(nil), do: nil
  defp format_trial_end(trial_end), do: DateTime.from_unix!(trial_end)
end
