defmodule MessagingService.Messaging.Provider do
  @moduledoc """
  Behaviour for all messaging providers (SMS/MMS and Email).
  """

  alias MessagingService.Messaging.Message
  alias MessagingService.Messaging.Types

  @doc """
  The result of sending an outbound message to the provider.
  """
  @type send_result :: {:ok, Message.t()} | {:error, term()}

  @callback name() :: atom()

  @doc """
  Sends an outbound message to the provider.
  """
  @callback send_outbound(Types.outbound_payload()) :: send_result

  @doc """
  Normalizes an inbound webhook payload to our unified struct.
  """
  @callback handle_inbound(map()) :: {:ok, Message.t()} | {:error, term()}
end
