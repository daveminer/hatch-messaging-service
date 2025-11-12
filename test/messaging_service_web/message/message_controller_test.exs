defmodule MessagingServiceWeb.MessageControllerTest do
  use MessagingServiceWeb.ConnCase, async: true

  alias MessagingService.Messaging.Message
  alias MessagingService.Repo

  # Helper to create a timestamp without microseconds
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  # Base params for different message types
  defp base_sms_webhook_params do
    %{
      "from" => "+15551234567",
      "to" => "+15559876543",
      "type" => "sms",
      "body" => "Hello world",
      "attachments" => [],
      "timestamp" => now(),
      "messaging_provider_id" => "twilio-msg-123"
    }
  end

  defp base_email_webhook_params do
    %{
      "from" => "sender@example.com",
      "to" => "receiver@example.com",
      "body" => "Email body content",
      "timestamp" => now(),
      "xillio_id" => "email-msg-789"
    }
  end

  defp base_sms_outbound_params do
    %{
      "from" => "+15551234567",
      "to" => "+15559876543",
      "type" => "sms",
      "body" => "Outbound SMS",
      "attachments" => [],
      "timestamp" => now()
    }
  end

  defp base_email_outbound_params do
    %{
      "from" => "sender@example.com",
      "to" => "receiver@example.com",
      "body" => "Outbound email body",
      "attachments" => [],
      "timestamp" => now()
    }
  end

  describe "POST /api/webhooks/sms - handle_inbound SMS" do
    test "successfully receives an inbound SMS webhook", %{conn: conn} do
      params = base_sms_webhook_params()
      conn = post(conn, ~p"/api/webhooks/sms", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"
      assert response["id"] != nil

      # Verify message was persisted
      message = Repo.get(Message, response["id"])
      assert message.direction == "inbound"
      assert message.type == "sms"
      assert message.from == params["from"]
      assert message.to == params["to"]
      assert message.body == params["body"]
    end

    test "successfully receives an inbound MMS webhook", %{conn: conn} do
      params =
        base_sms_webhook_params()
        |> Map.merge(%{
          "type" => "mms",
          "body" => "Check out this image",
          "attachments" => ["https://example.com/image.jpg"]
        })

      conn = post(conn, ~p"/api/webhooks/sms", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"

      message = Repo.get(Message, response["id"])
      assert message.type == "sms"
      assert message.attachments == ["https://example.com/image.jpg"]
    end

    test "rejects SMS webhook with invalid timestamp", %{conn: conn} do
      params = base_sms_webhook_params() |> Map.put("timestamp", "not-a-timestamp")
      conn = post(conn, ~p"/api/webhooks/sms", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_timestamp"
    end

    test "rejects SMS webhook with invalid phone number (not E.164)", %{conn: conn} do
      params = base_sms_webhook_params() |> Map.put("from", "5551234567")
      conn = post(conn, ~p"/api/webhooks/sms", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "must_be_e164_format"
    end

    test "handles invalid webhook payload gracefully", %{conn: conn} do
      conn = post(conn, ~p"/api/webhooks/sms", %{"invalid" => "payload"})
      assert conn.status in [400, 422]
    end
  end

  describe "POST /api/webhooks/email - handle_inbound Email" do
    test "successfully receives an inbound email webhook", %{conn: conn} do
      params = base_email_webhook_params()
      conn = post(conn, ~p"/api/webhooks/email", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"
      assert response["id"] != nil

      message = Repo.get(Message, response["id"])
      assert message.direction == "inbound"
      assert message.type == "email"
      assert message.from == params["from"]
      assert message.to == params["to"]
      assert message.body == params["body"]
    end

    test "handles quoted email addresses", %{conn: conn} do
      params =
        base_email_webhook_params()
        |> Map.merge(%{
          "from" => "\"sender@example.com\"",
          "to" => "\"receiver@example.com\""
        })

      conn = post(conn, ~p"/api/webhooks/email", params)
      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "sender@example.com"
      assert message.to == "receiver@example.com"
    end

    test "handles markdown-style email addresses", %{conn: conn} do
      params =
        base_email_webhook_params()
        |> Map.merge(%{
          "from" => "[sender@example.com](mailto:sender@example.com)",
          "to" => "[receiver@example.com](mailto:receiver@example.com)"
        })

      conn = post(conn, ~p"/api/webhooks/email", params)
      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "sender@example.com"
      assert message.to == "receiver@example.com"
    end

    test "rejects email webhook with invalid timestamp", %{conn: conn} do
      params = base_email_webhook_params() |> Map.put("timestamp", "invalid")
      conn = post(conn, ~p"/api/webhooks/email", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_timestamp"
    end

    test "rejects email webhook with invalid email address", %{conn: conn} do
      params = base_email_webhook_params() |> Map.put("from", "not-an-email")
      conn = post(conn, ~p"/api/webhooks/email", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_email"
    end
  end

  describe "POST /api/messages/sms - send_sms" do
    test "successfully sends an outbound SMS message", %{conn: conn} do
      params = base_sms_outbound_params()
      conn = post(conn, ~p"/api/messages/sms", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"
      assert response["id"] != nil

      message = Repo.get(Message, response["id"])
      assert message.direction == "outbound"
      assert message.type == "sms"
      assert message.from == params["from"]
      assert message.to == params["to"]
    end

    test "successfully sends an outbound MMS message", %{conn: conn} do
      params =
        base_sms_outbound_params()
        |> Map.merge(%{
          "type" => "mms",
          "body" => "Check this out",
          "attachments" => ["https://example.com/photo.jpg"]
        })

      conn = post(conn, ~p"/api/messages/sms", params)
      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.attachments == ["https://example.com/photo.jpg"]
    end

    test "rejects SMS with invalid phone number", %{conn: conn} do
      params = base_sms_outbound_params() |> Map.put("from", "invalid-phone")
      conn = post(conn, ~p"/api/messages/sms", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "must_be_e164_format"
    end

    test "rejects SMS with invalid timestamp", %{conn: conn} do
      params = base_sms_outbound_params() |> Map.put("timestamp", 12345)
      conn = post(conn, ~p"/api/messages/sms", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_timestamp"
    end

    test "rejects SMS with missing required fields", %{conn: conn} do
      conn = post(conn, ~p"/api/messages/sms", %{"from" => "+15551234567", "body" => "Message"})
      assert conn.status in [400, 422]
    end
  end

  describe "POST /api/messages/email - send_email" do
    test "successfully sends an outbound email message", %{conn: conn} do
      params = base_email_outbound_params()
      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"
      assert response["id"] != nil

      message = Repo.get(Message, response["id"])
      assert message.direction == "outbound"
      assert message.type == "email"
      assert message.from == params["from"]
      assert message.to == params["to"]
    end

    test "sends email with attachments", %{conn: conn} do
      params =
        base_email_outbound_params()
        |> Map.merge(%{
          "body" => "Email with attachment",
          "attachments" => ["https://example.com/document.pdf"]
        })

      conn = post(conn, ~p"/api/messages/email", params)
      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.attachments == ["https://example.com/document.pdf"]
    end

    test "rejects email with invalid email address", %{conn: conn} do
      params = base_email_outbound_params() |> Map.put("from", "invalid-email")
      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_email"
    end

    test "rejects email with invalid timestamp", %{conn: conn} do
      params = base_email_outbound_params() |> Map.put("timestamp", "not-a-date")
      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_timestamp"
    end

    test "rejects email with missing required fields", %{conn: conn} do
      conn =
        post(conn, ~p"/api/messages/email", %{
          "from" => "sender@example.com",
          "body" => "Email body"
        })

      assert conn.status in [400, 422]
    end
  end

  describe "edge cases" do
    test "handles international phone numbers correctly", %{conn: conn} do
      params =
        base_sms_outbound_params()
        |> Map.merge(%{
          "from" => "+447911123456",
          "to" => "+61412345678",
          "body" => "International SMS"
        })

      conn = post(conn, ~p"/api/messages/sms", params)
      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "+447911123456"
      assert message.to == "+61412345678"
    end

    test "handles complex email addresses", %{conn: conn} do
      params =
        base_email_outbound_params()
        |> Map.merge(%{
          "from" => "user+tag@example.co.uk",
          "to" => "another.user@subdomain.example.com"
        })

      conn = post(conn, ~p"/api/messages/email", params)
      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "user+tag@example.co.uk"
      assert message.to == "another.user@subdomain.example.com"
    end

    test "normalizes email addresses to lowercase", %{conn: conn} do
      params =
        base_email_outbound_params()
        |> Map.merge(%{
          "from" => "Sender@Example.COM",
          "to" => "Receiver@Example.COM"
        })

      conn = post(conn, ~p"/api/messages/email", params)
      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "sender@example.com"
      assert message.to == "receiver@example.com"
    end
  end
end
