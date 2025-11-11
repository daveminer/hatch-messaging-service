defmodule MessagingService.Messaging.Providers.Email do
  @behaviour MessagingService.Messaging.Provider

  alias MessagingService.Messaging.Message

  @impl true
  def name, do: :email

  @impl true
  def send_outbound(%{
        "direction" => "outbound",
        "from" => from,
        "to" => to,
        "type" => "email",
        "body" => body,
        "attachments" => attachments,
        "timestamp" => timestamp
      }) do
    case mock_email_service_call(from, to, body, attachments) do
      :ok ->
        {:ok,
         %Message{
           direction: "outbound",
           type: "email",
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

  def send_outbound(%{"type" => other}), do: {:error, {:invalid_payload, other}}

  @impl true
  def handle_inbound(%{
        "from" => from,
        "to" => to,
        "xillio_id" => _mpid,
        "body" => body_html,
        "timestamp" => ts
      }) do
    {:ok,
     %Message{
       direction: "inbound",
       type: "email",
       from: from,
       to: to,
       body: body_html || "",
       attachments: [],
       timestamp: ts
     }}
  rescue
    _ -> {:error, :invalid_payload}
  end

  defp mock_email_service_call(from, to, body, attachments) do
    _sendgrid_request_params = %{
      personalizations: [
        %{
          to: [to]
        }
      ],
      from: %{email: from},
      subject: "Test Email",
      content: [%{type: "text/html", value: body}],
      attachments: attachments
    }

    # Here we would make a request to the Sendgrid API to send the email

    case :rand.uniform(10) do
      1 -> {:error, 429}
      2 -> {:error, 500}
      _ -> :ok
    end
  end
end
