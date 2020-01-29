defprotocol Sanbase.Signal do
  def send(user_trigger)
end

defimpl Sanbase.Signal, for: Any do
  require Logger

  def send(%{
        trigger: %{settings: %{triggered?: false}}
      }) do
    warn_msg = "Trying to send a signal that is not triggered."
    Logger.warn(warn_msg)
    {:error, warn_msg}
  end

  def send(%{trigger: %{settings: %{channel: channel}}} = user_trigger) do
    # This will return a list of `{identifier, telegram_sent_status}` or `{:error, error}`
    # If a signal is sent to more than 1 channel this is handled properly by
    # the caller that puts the triggered identifiers in a map, so duplicates
    # disappear
    channel
    |> List.wrap()
    |> Enum.map(fn
      "telegram" -> send_telegram(user_trigger)
      "email" -> send_email(user_trigger)
      "web_push" -> []
    end)
    |> List.flatten()
  end

  def send_email(%{
        id: id,
        user: %Sanbase.Auth.User{
          email: email,
          user_settings: %{settings: %{signal_notify_email: true}}
        },
        trigger: %{
          settings: %{triggered?: true, payload: payload_map}
        }
      })
      when is_binary(email) and is_map(payload_map) do
    payload_map
    |> Enum.map(fn {identifier, payload} ->
      {identifier, do_send_email(email, payload, id)}
    end)
  end

  def send_email(%{
        user: %Sanbase.Auth.User{
          id: id,
          user_settings: %{settings: %{has_telegram_connected: false}}
        }
      }) do
    Logger.warn("User with id #{id} does not have an email linked, so a signal cannot be sent.")

    {:error, "No email linked for user with id #{id}"}
  end

  def send_telegram(%{
        user: %Sanbase.Auth.User{
          id: id,
          user_settings: %{settings: %{has_telegram_connected: false}}
        }
      }) do
    Logger.warn("User with id #{id} does not have a telegram linked, so a signal cannot be sent.")

    {:error, "No telegram linked for user with #{id}"}
  end

  def send_telegram(%{
        id: id,
        user: user,
        trigger: %{
          settings: %{triggered?: true, payload: payload_map}
        }
      })
      when is_map(payload_map) do
    payload_map
    |> Enum.map(fn {identifier, payload} ->
      {identifier, Sanbase.Telegram.send_message(user, extend_payload(payload, id))}
    end)
  end

  defp extend_payload(payload, user_trigger_id) do
    """
    #{payload}
    The signal was triggered by #{SanbaseWeb.Endpoint.show_signal_url(user_trigger_id)}
    """
  end

  defp do_send_email(email, payload, trigger_id) do
    Sanbase.MandrillApi.send("signals", email, %{
      payload: extend_payload(payload, trigger_id) |> Earmark.as_html!(breaks: true)
    })
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
