defmodule MessagingService.Messaging.Dispatcher do
  @moduledoc """
  Routes messages to providers and normalizes inbound payloads.
  """

  alias MessagingService.Messaging.{Types, Message}
  alias MessagingService.Messaging.Providers.{SMS, Email}
  alias MessagingService.Repo

  @provider_by_type %{
    "sms" => SMS,
    "email" => Email
  }

  @spec send_message(Types.outbound_payload()) ::
          {:ok, Message.t()} | {:error, term()}
  def send_message(%{"body" => body, "from" => from, "to" => to, "type" => type} = payload) do
    with {:ok, module} <- provider_for(type),
         {:ok, %{messaging_provider_id: messaging_provider_id}} <- module.send_outbound(payload) do
      nm =
        %Message{
          direction: :outbound,
          type: type,
          from: from,
          to: to,
          body: body,
          attachments: payload["attachments"] || [],
          timestamp: normalize_ts(payload["timestamp"]),
          provider: module.name(),
          provider_message_id: messaging_provider_id,
          metadata: %{}
        }

      Repo.insert!(nm)

      {:ok, nm}
    end
  end

  @spec handle_inbound(atom(), map()) :: {:ok, Message.t()} | {:error, term()}
  def handle_inbound(provider_name, raw_payload) do
    with {:ok, module} <- provider_for_name(provider_name),
         {:ok, nm} <- module.handle_inbound(raw_payload) do
      Repo.insert!(nm)

      {:ok, nm}
    end
  end

  defp provider_for(type) do
    case Map.fetch(@provider_by_type, type) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, {:unknown_provider_type, type}}
    end
  end

  defp provider_for_name(name) do
    module =
      case name do
        :sms -> SMSMock
        :email -> EmailMock
        _ -> nil
      end

    if module, do: {:ok, module}, else: {:error, {:unknown_provider, name}}
  end

  defp normalize_ts(nil), do: DateTime.utc_now()
  defp normalize_ts(%DateTime{} = dt), do: dt
  defp normalize_ts(ts) when is_binary(ts), do: DateTime.from_iso8601(ts) |> elem(1)
  defp normalize_ts(_), do: DateTime.utc_now()
end
