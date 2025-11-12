defmodule MessagingServiceWeb.ConversationController do
  use MessagingServiceWeb, :controller

  alias MessagingService.Messaging

  @doc """
  Lists all unique conversations with metadata.
  """
  def index(conn, _params) do
    conversations = Messaging.list_conversations()

    json(conn, %{conversations: conversations})
  end

  @doc """
  Shows all messages for a specific conversation. The conversation_id is
  expected to be in format "participant1::participant2"
  """
  def show(conn, %{"id" => conversation_id}) do
    case parse_conversation_id(conversation_id) do
      {:ok, {from, to}} ->
        messages = Messaging.list_conversation_messages(from, to)

        {participant1, participant2} = normalize_participants(from, to)

        json(conn, %{
          conversation: %{
            participant1: participant1,
            participant2: participant2,
            messages: messages
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  defp parse_conversation_id(conversation_id) do
    case String.split(conversation_id, "::") do
      [from, to] -> {:ok, {from, to}}
      _ -> {:error, "Invalid conversation ID format. Use 'participant1::participant2'"}
    end
  end

  defp normalize_participants(from, to) do
    [from, to] |> Enum.sort() |> List.to_tuple()
  end
end
