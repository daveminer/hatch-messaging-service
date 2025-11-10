defmodule MessagingService.Messaging.Providers.SMS do
  @behaviour MessagingService.Messaging.Provider

  alias MessagingService.Messaging.Message

  @impl true
  def name, do: :sms

  @impl true
  def send_outbound(%{"type" => "sms"} = _payload) do
    # Simulate HTTP call and random transient failures per spec (429/500)
    case maybe_fail() do
      :ok ->
        {:ok,
         %{
           provider: name(),
           messaging_provider_id: "sms-#{System.unique_integer([:positive])}",
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
        "type" => type_str,
        "messaging_provider_id" => mpid,
        "body" => body,
        "attachments" => attachments,
        "timestamp" => ts
      }) do
    {:ok,
     %Message{
       direction: :inbound,
       type: str_to_type(type_str),
       from: from,
       to: to,
       body: body || "",
       attachments: attachments || [],
       timestamp: parse_ts(ts),
       provider: name(),
       provider_message_id: mpid,
       metadata: %{}
     }}
  rescue
    _ -> {:error, :invalid_payload}
  end

  defp str_to_type("sms"), do: :sms
  defp str_to_type("mms"), do: :mms
  defp str_to_type(_), do: :sms

  defp parse_ts(ts) when is_binary(ts), do: DateTime.from_iso8601(ts) |> elem(1)
  defp parse_ts(%DateTime{} = dt), do: dt
  defp parse_ts(_), do: DateTime.utc_now()

  # Randomly simulate 429/500 to exercise retry logic
  defp maybe_fail do
    case :rand.uniform(10) do
      1 -> {:error, 429}
      2 -> {:error, 500}
      _ -> :ok
    end
  end
end
