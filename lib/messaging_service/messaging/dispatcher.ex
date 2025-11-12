defmodule MessagingService.Messaging.Dispatcher do
  @moduledoc """
  Routes messages to providers and normalizes inbound payloads.
  """

  alias MessagingService.Messaging.{Types, Message}
  alias MessagingService.Messaging.Providers.{SMS, Email}
  alias MessagingService.Repo

  @provider_by_type %{
    "sms" => SMS,
    "mms" => SMS,
    "email" => Email
  }

  @spec dispatch(Types.outbound_payload()) :: {:ok, Message.t()} | {:error, term()}
  def dispatch(%{"direction" => direction, "type" => type} = payload) do
    with {:ok, module} <- provider_for(type) do
      case direction do
        "outbound" -> handle_outbound(module, payload)
        "inbound" -> handle_inbound(module, payload)
        _ -> {:error, {:invalid_direction, direction}}
      end
    end
  end

  defp handle_outbound(module, payload) do
    with {:ok, %Message{} = msg} <- module.send_outbound(payload) do
      Repo.insert(msg)
    end
  end

  defp handle_inbound(module, payload) do
    with {:ok, %Message{} = msg} <- module.handle_inbound(payload) do
      Repo.insert(msg)
    end
  end

  defp provider_for(type) do
    case Map.fetch(@provider_by_type, type) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, {:unknown_provider_type, type}}
    end
  end
end
