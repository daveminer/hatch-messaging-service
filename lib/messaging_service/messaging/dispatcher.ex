defmodule MessagingService.Messaging.Dispatcher do
  @moduledoc """
  Routes messages to providers and normalizes inbound payloads.
  """

  alias MessagingService.Messaging.{Types, Message}
  alias MessagingService.Messaging.Providers.{SMS, Email}

  @provider_by_type %{
    "sms" => SMS,
    "email" => Email
  }

  # ---- Outbound -------------------------------------------------------------

  @spec send_message(Types.outbound_payload()) ::
          {:ok, Message.t()} | {:error, term()}
  def send_message(%{"type" => type} = payload) do
    with {:ok, module} <- provider_for(type),
         {:ok, result} <- module.send_outbound(payload) do
      nm =
        %Message{
          direction: :outbound,
          type: type,
          from: payload["from"],
          to: payload["to"],
          body: payload["body"] || "",
          attachments: payload["attachments"] || [],
          timestamp: normalize_ts(payload["timestamp"]),
          provider: module.name(),
          provider_message_id: result.messaging_provider_id,
          metadata: %{}
        }

      # TODO: persist message + upsert conversation(transaction!):
      #   - conversation_key = conversation_key(nm.from, nm.to)
      #   - Repo.insert!(...) / Repo.update!(...)
      {:ok, nm}
    end
  end

  # ---- Inbound (webhooks) ---------------------------------------------------

  @spec handle_inbound(atom(), map()) :: {:ok, Message.t()} | {:error, term()}
  def handle_inbound(provider_name, raw_payload) do
    with {:ok, module} <- provider_for_name(provider_name),
         {:ok, nm} <- module.handle_inbound(raw_payload) do
      # TODO: persist message + upsert conversation here as well
      {:ok, nm}
    end
  end

  # ---- Helpers --------------------------------------------------------------

  defp provider_for(type) do
    case Map.fetch(@provider_by_type, type) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, {:unknown_type, type}}
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

  @doc """
  Stable conversation key: participants only (provider-agnostic).
  """
  def conversation_key(a, b) when is_binary(a) and is_binary(b) do
    [a, b] |> Enum.map(&String.trim/1) |> Enum.sort() |> Enum.join("::")
  end
end
