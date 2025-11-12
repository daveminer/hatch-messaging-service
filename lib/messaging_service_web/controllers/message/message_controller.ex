defmodule MessagingServiceWeb.MessageController do
  use MessagingServiceWeb, :controller

  alias MessagingService.Messaging.Dispatcher
  alias MessagingService.Messaging.Message

  require Logger

  @required_fields ["from", "to", "type", "body", "attachments"]

  @doc """
  Handle webhooks for inbound email, SMS, and MMS.
  """
  # SMS/MMS
  def handle_inbound(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "type" => type,
          "messaging_provider_id" => _messaging_provider_id,
          "body" => _body,
          "timestamp" => _timestamp,
          "attachments" => _attachments
        } = params
      )
      when type in ["sms", "mms"] do
    with {:ok, validated_params} <- validate_sms_inbound_payload(params) do
      validated_params
      |> Map.put("direction", "inbound")
      |> dispatch_message()
      |> send_response(conn)
    else
      {:error, reason} -> send_response({:error, reason}, conn)
    end
  end

  # Email
  def handle_inbound(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "xillio_id" => _mpid,
          "body" => _body,
          "timestamp" => _timestamp
        } = params
      ) do
    with {:ok, validated_params} <- validate_email_inbound_payload(params) do
      validated_params
      |> Map.put("type", "email")
      |> Map.put("direction", "inbound")
      |> dispatch_message()
      |> send_response(conn)
    else
      {:error, reason} -> send_response({:error, reason}, conn)
    end
  end

  def handle_inbound(conn, params) do
    Logger.warning("An invalid webhook payload was received: #{inspect(params |> Map.keys())}")
    render(conn, :bad_request)
  end

  @doc """
  Send an SMS/MMS or email message to a recipient via API call
  """
  def send_email(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "body" => _body,
          "attachments" => _attachments,
          "timestamp" => _timestamp
        } = params
      ) do
    with {:ok, validated_params} <- validate_email_outbound_payload(params) do
      validated_params
      |> Map.put("direction", "outbound")
      |> Map.put("type", "email")
      |> dispatch_message()
      |> send_response(conn)
    else
      {:error, reason} -> send_response({:error, reason}, conn)
    end
  end

  def send_email(conn, params),
    do: send_missing_fields_bad_request(conn, params)

  def send_sms(
        conn,
        %{
          "from" => _from,
          "to" => _to,
          "body" => _body,
          "attachments" => _attachments,
          "timestamp" => _timestamp,
          "type" => _type
        } = params
      ) do
    with {:ok, validated_params} <- validate_sms_outbound_payload(params) do
      validated_params
      |> Map.put("direction", "outbound")
      |> Map.put("type", "sms")
      |> dispatch_message()
      |> send_response(conn)
    else
      {:error, reason} -> send_response({:error, reason}, conn)
    end
  end

  def send_sms(conn, params),
    do: send_missing_fields_bad_request(conn, params)

  defp dispatch_message(params) do
    case Dispatcher.dispatch(params) do
      {:ok, %Message{id: id}} ->
        {:ok, id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_missing_fields_bad_request(conn, params) do
    render(conn, :bad_request,
      missing_fields:
        @required_fields |> Enum.filter(fn field -> !Map.has_key?(params, field) end)
    )
  end

  defp send_response({:ok, message_id}, conn) do
    send_resp(conn, 202, Jason.encode!(%{status: "sent", id: message_id}))
  end

  defp send_response({:error, reason}, conn) do
    send_resp(conn, 422, Jason.encode!(%{error: inspect(reason)}))
  end

  defp validate_sms_inbound_payload(params) do
    with {:ok, timestamp} <- parse_timestamp(params["timestamp"]),
         {:ok, from} <- validate_phone_number(params["from"]),
         {:ok, to} <- validate_phone_number(params["to"]) do
      {:ok, %{params | "from" => from, "to" => to, "timestamp" => timestamp}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_sms_outbound_payload(params) do
    with {:ok, timestamp} <- parse_timestamp(params["timestamp"]),
         {:ok, from} <- validate_phone_number(params["from"]),
         {:ok, to} <- validate_phone_number(params["to"]) do
      {:ok, %{params | "from" => from, "to" => to, "timestamp" => timestamp}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_email_inbound_payload(params) do
    with {:ok, timestamp} <- parse_timestamp(params["timestamp"]),
         {:ok, from} <- validate_email(params["from"]),
         {:ok, to} <- validate_email(params["to"]) do
      {:ok, %{params | "from" => from, "to" => to, "timestamp" => timestamp}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_email_outbound_payload(params) do
    with {:ok, timestamp} <- parse_timestamp(params["timestamp"]),
         {:ok, from} <- validate_email(params["from"]),
         {:ok, to} <- validate_email(params["to"]) do
      {:ok, %{params | "from" => from, "to" => to, "timestamp" => timestamp}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, _} -> {:error, {:invalid_timestamp, timestamp}}
    end
  end

  defp parse_timestamp(timestamp), do: {:error, {:invalid_timestamp, timestamp}}

  defp validate_email(email) when is_binary(email) do
    # Extract email from various formats
    extracted_email =
      cond do
        # Markdown link format: "[user@example.com](mailto:user@example.com)"
        String.contains?(email, "](mailto:") ->
          case Regex.run(~r/\[([^\]]+)\]\(mailto:([^\)]+)\)/, email) do
            [_, display_email, _mailto_email] -> display_email
            _ -> email
          end

        # Quoted format: "user@example.com"
        String.starts_with?(email, "\"") and String.ends_with?(email, "\"") ->
          email |> String.trim("\"")

        # Plain format
        true ->
          email
      end

    # Basic email validation: local_part@domain
    # Allows alphanumerics, dots, hyphens, underscores, and plus signs
    email_regex =
      ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/

    case Regex.match?(email_regex, extracted_email) do
      true -> {:ok, String.downcase(extracted_email)}
      false -> {:error, {:invalid_email, email}}
    end
  end

  defp validate_email(email), do: {:error, {:invalid_email, email}}

  defp validate_phone_number(phone_number) when is_binary(phone_number) do
    # E.164 format: +[country code][number]
    # Should be 10-15 digits after the +
    case Regex.match?(~r/^\+[1-9]\d{9,14}$/, phone_number) do
      true -> {:ok, phone_number}
      false -> {:error, {:must_be_e164_format, phone_number}}
    end
  end

  defp validate_phone_number(phone_number), do: {:error, {:must_be_e164_format, phone_number}}
end
