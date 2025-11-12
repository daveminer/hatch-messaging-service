defmodule MessagingService.Messaging.Message do
  @moduledoc """
  Unified, provider-agnostic representation for a message.
  This is an Ecto schema that persists messages to the database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :direction,
             :type,
             :from,
             :to,
             :body,
             :conversation_key,
             :attachments,
             :timestamp,
             :metadata
           ]}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "messages" do
    # :inbound | :outbound
    field :direction, :string
    # :sms | :email
    field :type, :string
    field :from, :string
    field :to, :string
    field :body, :string
    field :conversation_key, :string
    field :attachments, {:array, :string}

    field :timestamp, :utc_datetime
    field :metadata, :map

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a message.
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :direction,
      :type,
      :from,
      :to,
      :body,
      :attachments,
      :timestamp,
      :metadata
    ])
    |> validate_required([
      :direction,
      :type,
      :from,
      :to,
      :body,
      :timestamp
    ])
    |> validate_inclusion(:direction, ["inbound", "outbound"])
    |> validate_inclusion(:type, ["sms", "email", "mms"])
  end
end
