defmodule MessagingService.Messaging.Message do
  @moduledoc """
  Unified, provider-agnostic representation for a message.
  This is an Ecto schema that persists messages to the database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "messages" do
    # :inbound | :outbound
    field :direction, :string
    # :sms | :email
    field :type, :string
    field :from, :string
    field :to, :string
    field :body, :string
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
      :provider,
      :provider_message_id,
      :metadata
    ])
    |> validate_required([
      :direction,
      :type,
      :from,
      :to,
      :body,
      :timestamp,
      :provider,
      :provider_message_id
    ])
    |> validate_inclusion(:direction, ["inbound", "outbound"])
    |> validate_inclusion(:type, ["sms", "email"])
  end

  @doc """
  Generate a direction-agnostic conversation key from the message's from/to fields.
  """
  # def conversation_key(%__MODULE__{from: from, to: to}) do
  #   [from, to] |> Enum.sort() |> Enum.join(":")
  # end
end
