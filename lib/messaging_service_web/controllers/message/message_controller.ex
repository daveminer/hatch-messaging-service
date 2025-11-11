defmodule MessagingServiceWeb.MessageController do
  use MessagingServiceWeb, :controller

  alias MessagingService.Messaging.Dispatcher
  alias MessagingService.Messaging.Message

  require Logger

  @required_fields ["from", "to", "type", "body", "attachments"]

  @doc """
  Handle webhooks for inbound email, SMS, and MMS.
  """
  # SMS/MMS
  def handle_inbound(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "type" => type,
          "messaging_provider_id" => _messaging_provider_id,
          "body" => _body,
          "timestamp" => _timestamp,
          "attachments" => _attachments
        } = params
      )
      when type in ["sms", "mms"] do
    dispatch_message(
      params
      |> Map.put("direction", "inbound")
    )
    |> send_response(conn)
  end

  # Email
  def handle_inbound(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "xillio_id" => _mpid,
          "body" => _body,
          "timestamp" => _timestamp
        } = params
      ) do
    dispatch_message(
      params
      |> Map.put("type", "email")
      |> Map.put("direction", "inbound")
    )
    |> send_response(conn)
  end

  def handle_inbound(conn, params) do
    Logger.warning("An invalid webhook payload was received: #{inspect(params |> Map.keys())}")
    render(conn, :bad_request)
  end

  @doc """
  Send an SMS/MMS or email message to a recipient via API call
  """
  def send_email(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "body" => _body,
          "attachments" => _attachments,
          "timestamp" => _timestamp
        } = params
      ) do
    dispatch_message(
      params
      |> Map.put("direction", "outbound")
      |> Map.put("type", "email")
    )
    |> send_response(conn)
  end

  def send_email(conn, params),
    do: send_missing_fields_bad_request(conn, params)

  def send_sms(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "body" => _body,
          "attachments" => _attachments,
          "timestamp" => _timestamp,
          "type" => _type
        } = params
      ) do
    dispatch_message(
      params
      |> Map.put("direction", "outbound")
    )
    |> send_response(conn)
  end

  def send_sms(conn, params),
    do: send_missing_fields_bad_request(conn, params)

  defp dispatch_message(params) do
    case Dispatcher.dispatch(params) do
      {:ok, %Message{id: id}} ->
        {:ok, id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_missing_fields_bad_request(conn, params) do
    render(conn, :bad_request,
      missing_fields:
        @required_fields |> Enum.filter(fn field -> !Map.has_key?(params, field) end)
    )
  end

  defp send_response({:ok, message_id}, conn) do
    send_resp(conn, 202, Jason.encode!(%{status: "sent", id: message_id}))
  end

  defp send_response({:error, reason}, conn) do
    send_resp(conn, 422, Jason.encode!(%{error: inspect(reason)}))
  end
end
