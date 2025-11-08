defmodule Hatch.Messaging.Provider do
  @moduledoc """
  Behaviour for all messaging providers (SMS/MMS and Email).
  """

  @type msg_type :: :sms | :email

  @type outbound_payload :: %{
          required(:from) => String.t(),
          required(:to) => String.t(),
          required(:type) => msg_type(),
          required(:body) => String.t(),
          optional(:attachments) => [String.t()] | nil,
          optional(:timestamp) => DateTime.t() | String.t() | nil
        }

  @doc """
  The result of sending an outbound message to the provider.
  """
  @type send_result ::
          {:ok, %{provider: atom(), messaging_provider_id: String.t(), status: :queued | :sent}}
          | {:error, term()}

  @callback name() :: atom()

  @doc """
  Sends an outbound message to the provider.
  """
  @callback send_outbound(outbound_payload()) :: send_result

  @doc """
  Normalizes an inbound webhook payload to our unified struct.
  """
  @callback handle_inbound(map()) ::
              {:ok, NormalizedMessage.t()} | {:error, term()}
end
