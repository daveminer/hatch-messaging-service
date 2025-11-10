defmodule MessagingService.Messaging.Message do
  @moduledoc """
  Unified, provider-agnostic in-memory representation for a message.
  Persist this shape (or a close variant) to your DB.
  """

  @enforce_keys [
    :direction,
    :type,
    :from,
    :to,
    :body,
    :timestamp,
    :provider,
    :provider_message_id
  ]

  defstruct [
    # :inbound | :outbound
    :direction,
    # :sms | :mms | :email
    :type,
    :from,
    :to,
    :body,
    :attachments,
    # DateTime.t()
    :timestamp,
    # :sms | :email | :<your-provider>
    :provider,
    :provider_message_id,
    # anything extra (e.g., headers)
    metadata: %{}
  ]

  @type t :: %__MODULE__{}
end
