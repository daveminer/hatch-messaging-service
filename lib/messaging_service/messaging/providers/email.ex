defmodule MessagingService.Messaging.Providers.Email do
  @behaviour MessagingService.Messaging.Provider

  alias MessagingService.Messaging.Message

  @impl true
  def name, do: :email

  @impl true
  def send_outbound(%{type: :email}) do
    case maybe_fail() do
      :ok ->
        {:ok,
         %{
           provider: name(),
           messaging_provider_id: "email-#{System.unique_integer([:positive])}",
           status: :queued
         }}

      {:error, code} ->
        {:error, {:http_error, code}}
    end
  end

  def send_outbound(%{type: other}), do: {:error, {:invalid_type, other}}

  @impl true
  def handle_inbound(%{
        "from" => from,
        "to" => to,
        "xillio_id" => mpid,
        "body" => body_html,
        "attachments" => attachments,
        "timestamp" => ts
      }) do
    {:ok,
     %Message{
       direction: :inbound,
       type: :email,
       from: from,
       to: to,
       body: body_html || "",
       attachments: attachments || [],
       timestamp: parse_ts(ts),
       provider: name(),
       provider_message_id: mpid,
       metadata: %{}
     }}
  rescue
    _ -> {:error, :invalid_payload}
  end

  defp parse_ts(ts) when is_binary(ts), do: DateTime.from_iso8601(ts) |> elem(1)
  defp parse_ts(%DateTime{} = dt), do: dt
  defp parse_ts(_), do: DateTime.utc_now()

  defp maybe_fail do
    case :rand.uniform(10) do
      1 -> {:error, 429}
      2 -> {:error, 500}
      _ -> :ok
    end
  end
end
