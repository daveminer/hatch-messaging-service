defmodule MessagingService.Messaging.Types do
  @moduledoc false

  @type msg_type :: :sms | :email

  @type outbound_payload :: %{
          required(:from) => String.t(),
          required(:to) => String.t(),
          required(:type) => msg_type(),
          required(:body) => String.t(),
          optional(:attachments) => [String.t()] | nil,
          optional(:timestamp) => DateTime.t() | String.t() | nil
        }
end
