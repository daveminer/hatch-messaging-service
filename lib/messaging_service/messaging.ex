defmodule MessagingService.Messaging do
  @moduledoc """
  The Messaging context for managing messages.
  """

  import Ecto.Query, warn: false
  alias MessagingService.Repo
  alias MessagingService.Messaging.Message

  @doc """
  Returns the list of messages.

  ## Examples

      iex> list_messages()
      [%Message{}, ...]

  """
  def list_messages do
    Repo.all(Message)
  end

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Message does not exist.

  ## Examples

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(message, %{field: new_value})
      {:ok, %Message{}}

      iex> update_message(message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Lists messages by direction (inbound or outbound).

  ## Examples

      iex> list_messages_by_direction("inbound")
      [%Message{}, ...]

  """
  def list_messages_by_direction(direction) do
    Message
    |> where([m], m.direction == ^direction)
    |> order_by([m], desc: m.timestamp)
    |> Repo.all()
  end

  @doc """
  Lists messages by type (sms or email).

  ## Examples

      iex> list_messages_by_type("sms")
      [%Message{}, ...]

  """
  def list_messages_by_type(type) do
    Message
    |> where([m], m.type == ^type)
    |> order_by([m], desc: m.timestamp)
    |> Repo.all()
  end

  @doc """
  Lists messages for a conversation between two parties.

  Uses LEAST/GREATEST predicate to leverage the expression index for efficient queries.

  ## Examples

      iex> list_conversation_messages("+15551234567", "+15559876543")
      [%Message{}, ...]

  """
  def list_conversation_messages(from, to) do
    # Normalize the from/to pair to match the expression index
    {lo, hi} = normalize_conversation_pair(from, to)

    Message
    |> where(
      [m],
      fragment("LEAST(?, ?) = ? AND GREATEST(?, ?) = ?", m.from, m.to, ^lo, m.from, m.to, ^hi)
    )
    |> order_by([m], asc: m.timestamp)
    |> Repo.all()
  end

  defp normalize_conversation_pair(from, to) do
    [from, to] |> Enum.sort() |> List.to_tuple()
  end

  @doc """
  Gets a message by provider message ID.

  ## Examples

      iex> get_message_by_provider_id("twilio-123")
      %Message{}

      iex> get_message_by_provider_id("unknown")
      nil

  """
  def get_message_by_provider_id(provider_message_id) do
    Repo.get_by(Message, provider_message_id: provider_message_id)
  end

  @doc """
  Groups by the conversation_key and returns conversation metadata.
  """
  def list_conversations do
    from(m in Message,
      group_by: m.conversation_key,
      select: %{
        conversation_key: m.conversation_key,
        participant1: fragment("SPLIT_PART(?, '::', 1)", m.conversation_key),
        participant2: fragment("SPLIT_PART(?, '::', 2)", m.conversation_key),
        message_count: count(m.id),
        latest_message_at: max(m.timestamp),
        latest_message_body:
          fragment(
            "(SELECT body FROM messages m2 WHERE m2.conversation_key = ? ORDER BY m2.timestamp DESC LIMIT 1)",
            m.conversation_key
          )
      },
      order_by: [desc: max(m.timestamp)]
    )
    |> Repo.all()
  end
end
