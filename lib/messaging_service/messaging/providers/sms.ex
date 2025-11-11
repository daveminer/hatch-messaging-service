defmodule MessagingService.Messaging.Providers.SMS do
  @behaviour MessagingService.Messaging.Provider

  alias MessagingService.Messaging.Message

  @impl true
  def name, do: :sms

  @impl true
  def send_outbound(
        %{
          "direction" => "outbound",
          "from" => from,
          "to" => to,
          "type" => type,
          "body" => body,
          "attachments" => attachments,
          "timestamp" => timestamp
        } = _payload
      )
      when type in ["sms", "mms"] do
    # Simulate HTTP call and random transient failures per spec (429/500)
    case mock_sms_service_call(from, to, body, attachments) do
      :ok ->
        {:ok,
         %Message{
           direction: "outbound",
           type: "sms",
           from: from,
           to: to,
           body: body,
           attachments: attachments,
           timestamp: timestamp
         }}

      {:error, code} ->
        {:error, {:http_error, code}}
    end
  end

  def send_outbound(%{type: other}), do: {:error, {:invalid_sms_outbound_payload, other}}

  @impl true
  def handle_inbound(%{
        "from" => from,
        "to" => to,
        "type" => type,
        "messaging_provider_id" => mpid,
        "body" => body,
        "attachments" => attachments,
        "timestamp" => ts
      })
      when type in ["sms", "mms"] do
    %Message{
      direction: "inbound",
      type: type,
      from: from,
      to: to,
      body: body || "",
      attachments: attachments || [],
      timestamp: ts,
      metadata: %{
        messaging_provider_id: mpid
      }
    }
  end

  def handle_inbound(%{type: other}), do: {:error, {:invalid_sms_webhook_payload, other}}

  defp mock_sms_service_call(from, to, body, attachments) do
    _twilio_request_params = %{
      from: from,
      to: to,
      body: body,
      attachments: attachments
    }

    # Here we would make a request to the Twilio API to send the SMS

    case :rand.uniform(10) do
      1 -> {:error, 429}
      2 -> {:error, 500}
      _ -> :ok
    end
  end
end
