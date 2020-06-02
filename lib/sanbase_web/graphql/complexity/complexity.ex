defmodule SanbaseWeb.Graphql.Complexity do
  require Logger

  @compile :inline_list_funcs
  @compile inline: [
             calculate_complexity: 3,
             interval_seconds: 1,
             years_difference_weighted: 2,
             get_metric_name: 1
           ]
  @doc ~S"""
  Internal services use basic authentication. Return complexity = 0 to allow them
  to access everything without limits.
  """
  def from_to_interval(_, _, %{context: %{auth: %{auth_method: :basic}}}) do
    # Does not pattern match on `%Absinthe.Complexity{}` so `%Absinthe.Resolution{}`
    # can be passed. This is possible because only the context is used
    0
  end

  def from_to_interval(
        args,
        child_complexity,
        %{context: %{auth: %{subscription: subscription}}} = struct
      )
      when not is_nil(subscription) do
    complexity = calculate_complexity(args, child_complexity, struct)

    case Sanbase.Billing.Plan.plan_atom_name(subscription.plan) do
      :free -> complexity
      :basic -> div(complexity, 2)
      :pro -> div(complexity, 3)
      :premium -> div(complexity, 5)
      :custom -> div(complexity, 5)
    end
  end

  @doc ~S"""
  Returns the complexity of the query. It is the number of intervals in the period
  'from-to' multiplied by the child complexity. The child complexity is the number
  of fields that will be returned for a single price point. The calculation is done
  based only on the supplied arguments and avoids accessing the DB if the query
  is rejected.
  """
  def from_to_interval(%{} = args, child_complexity, struct) do
    calculate_complexity(args, child_complexity, struct)
  end

  # Private functions

  defp calculate_complexity(%{from: from, to: to} = args, child_complexity, struct) do
    seconds_difference = Timex.diff(from, to, :seconds) |> abs
    years_difference_weighted = years_difference_weighted(from, to)
    interval_seconds = interval_seconds(args) |> max(1)
    metric = get_metric_name(struct)

    complexity_weight =
      with metric when is_binary(metric) <- metric,
           weight when is_number(weight) <- Sanbase.Metric.complexity_weight(metric) do
        weight
      else
        _ -> 1
      end

    (child_complexity * (seconds_difference / interval_seconds) * years_difference_weighted *
       complexity_weight)
    |> Sanbase.Math.to_integer()
  end

  defp get_metric_name(%{source: %{metric: metric}}), do: metric

  defp get_metric_name(_) do
    Process.get(:__metric_name_from_get_metric_api__)
  end

  defp interval_seconds(args) do
    case Map.get(args, :interval, "") do
      "" -> "1d"
      interval -> interval
    end
    |> Sanbase.DateTimeUtils.str_to_sec()
  end

  defp years_difference_weighted(from, to) do
    Timex.diff(from, to, :years) |> abs |> max(2) |> div(2)
  end
end
