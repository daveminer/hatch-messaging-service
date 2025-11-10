defmodule MessagingServiceWeb.MessageController do
  use MessagingServiceWeb, :controller

  alias MessagingService.Messaging.Dispatcher
  alias MessagingService.Messaging.Message

  @required_fields ["from", "to", "type", "body", "attachments"]
  def send_message(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "type" => _type,
          "body" => _body,
          "attachments" => _attachments
        } = params
      ) do
    case Dispatcher.send_message(params) do
      {:ok, %Message{provider_message_id: provider_message_id}} ->
        send_resp(conn, 202, Jason.encode!(%{status: "queued", id: provider_message_id}))

      {:error, reason} ->
        send_resp(conn, 422, Jason.encode!(%{error: inspect(reason)}))
    end
  end

  def send_message(conn, params),
    do:
      render(conn, :bad_request,
        missing_fields:
          @required_fields |> Enum.filter(fn field -> !Map.has_key?(params, field) end)
      )
end
