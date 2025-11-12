defmodule MessagingServiceWeb.MessageControllerTest do
  use MessagingServiceWeb.ConnCase, async: true

  alias MessagingService.Messaging.Message
  alias MessagingService.Repo

  # Helper to create a timestamp without microseconds
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  describe "POST /api/webhooks/sms - handle_inbound SMS" do
    test "successfully receives an inbound SMS webhook", %{conn: conn} do
      params = %{
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "Hello world",
        "attachments" => [],
        "timestamp" => now(),
        "messaging_provider_id" => "twilio-msg-123"
      }

      conn = post(conn, ~p"/api/webhooks/sms", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"
      assert response["id"] != nil

      # Verify message was persisted
      message = Repo.get(Message, response["id"])
      assert message.direction == "inbound"
      assert message.type == "sms"
      assert message.from == "+15551234567"
      assert message.to == "+15559876543"
      assert message.body == "Hello world"
    end

    test "successfully receives an inbound MMS webhook", %{conn: conn} do
      params = %{
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "mms",
        "body" => "Check out this image",
        "attachments" => ["https://example.com/image.jpg"],
        "timestamp" => now(),
        "messaging_provider_id" => "twilio-msg-456"
      }

      conn = post(conn, ~p"/api/webhooks/sms", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"

      message = Repo.get(Message, response["id"])
      assert message.type == "sms"
      assert message.attachments == ["https://example.com/image.jpg"]
    end

    test "rejects SMS webhook with invalid timestamp", %{conn: conn} do
      params = %{
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "Hello",
        "attachments" => [],
        "timestamp" => "not-a-timestamp",
        "messaging_provider_id" => "twilio-123"
      }

      conn = post(conn, ~p"/api/webhooks/sms", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_timestamp"
    end

    test "rejects SMS webhook with invalid phone number (not E.164)", %{conn: conn} do
      params = %{
        "from" => "5551234567",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "Hello",
        "attachments" => [],
        "timestamp" => now(),
        "messaging_provider_id" => "twilio-123"
      }

      conn = post(conn, ~p"/api/webhooks/sms", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "must_be_e164_format"
    end

    test "handles invalid webhook payload gracefully", %{conn: conn} do
      params = %{
        "invalid" => "payload"
      }

      conn = post(conn, ~p"/api/webhooks/sms", params)

      # Should get a bad request response
      assert conn.status in [400, 422]
    end
  end

  describe "POST /api/webhooks/email - handle_inbound Email" do
    test "successfully receives an inbound email webhook", %{conn: conn} do
      params = %{
        "from" => "sender@example.com",
        "to" => "receiver@example.com",
        "body" => "Email body content",
        "timestamp" => now(),
        "xillio_id" => "email-msg-789"
      }

      conn = post(conn, ~p"/api/webhooks/email", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"
      assert response["id"] != nil

      message = Repo.get(Message, response["id"])
      assert message.direction == "inbound"
      assert message.type == "email"
      assert message.from == "sender@example.com"
      assert message.to == "receiver@example.com"
      assert message.body == "Email body content"
    end

    test "handles quoted email addresses", %{conn: conn} do
      params = %{
        "from" => "\"sender@example.com\"",
        "to" => "\"receiver@example.com\"",
        "body" => "Email body",
        "timestamp" => now(),
        "xillio_id" => "email-123"
      }

      conn = post(conn, ~p"/api/webhooks/email", params)

      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "sender@example.com"
      assert message.to == "receiver@example.com"
    end

    test "handles markdown-style email addresses", %{conn: conn} do
      params = %{
        "from" => "[sender@example.com](mailto:sender@example.com)",
        "to" => "[receiver@example.com](mailto:receiver@example.com)",
        "body" => "Email body",
        "timestamp" => now(),
        "xillio_id" => "email-456"
      }

      conn = post(conn, ~p"/api/webhooks/email", params)

      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "sender@example.com"
      assert message.to == "receiver@example.com"
    end

    test "rejects email webhook with invalid timestamp", %{conn: conn} do
      params = %{
        "from" => "sender@example.com",
        "to" => "receiver@example.com",
        "body" => "Email body",
        "timestamp" => "invalid",
        "xillio_id" => "email-789"
      }

      conn = post(conn, ~p"/api/webhooks/email", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_timestamp"
    end

    test "rejects email webhook with invalid email address", %{conn: conn} do
      params = %{
        "from" => "not-an-email",
        "to" => "receiver@example.com",
        "body" => "Email body",
        "timestamp" => now(),
        "xillio_id" => "email-999"
      }

      conn = post(conn, ~p"/api/webhooks/email", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_email"
    end
  end

  describe "POST /api/messages/sms - send_sms" do
    test "successfully sends an outbound SMS message", %{conn: conn} do
      params = %{
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "Outbound SMS",
        "attachments" => [],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/sms", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"
      assert response["id"] != nil

      message = Repo.get(Message, response["id"])
      assert message.direction == "outbound"
      assert message.type == "sms"
      assert message.from == "+15551234567"
      assert message.to == "+15559876543"
    end

    test "successfully sends an outbound MMS message", %{conn: conn} do
      params = %{
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "mms",
        "body" => "Check this out",
        "attachments" => ["https://example.com/photo.jpg"],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/sms", params)

      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.attachments == ["https://example.com/photo.jpg"]
    end

    test "rejects SMS with invalid phone number", %{conn: conn} do
      params = %{
        "from" => "invalid-phone",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "Message",
        "attachments" => [],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/sms", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "must_be_e164_format"
    end

    test "rejects SMS with invalid timestamp", %{conn: conn} do
      params = %{
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "Message",
        "attachments" => [],
        "timestamp" => 12345
      }

      conn = post(conn, ~p"/api/messages/sms", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_timestamp"
    end

    test "rejects SMS with missing required fields", %{conn: conn} do
      params = %{
        "from" => "+15551234567",
        "body" => "Message"
      }

      conn = post(conn, ~p"/api/messages/sms", params)

      # Should get a bad request response with missing fields
      assert conn.status in [400, 422]
    end
  end

  describe "POST /api/messages/email - send_email" do
    test "successfully sends an outbound email message", %{conn: conn} do
      params = %{
        "from" => "sender@example.com",
        "to" => "receiver@example.com",
        "body" => "Outbound email body",
        "attachments" => [],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 202)
      assert response["status"] == "sent"
      assert response["id"] != nil

      message = Repo.get(Message, response["id"])
      assert message.direction == "outbound"
      assert message.type == "email"
      assert message.from == "sender@example.com"
      assert message.to == "receiver@example.com"
    end

    test "sends email with attachments", %{conn: conn} do
      params = %{
        "from" => "sender@example.com",
        "to" => "receiver@example.com",
        "body" => "Email with attachment",
        "attachments" => ["https://example.com/document.pdf"],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.attachments == ["https://example.com/document.pdf"]
    end

    test "rejects email with invalid email address", %{conn: conn} do
      params = %{
        "from" => "invalid-email",
        "to" => "receiver@example.com",
        "body" => "Email body",
        "attachments" => [],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_email"
    end

    test "rejects email with invalid timestamp", %{conn: conn} do
      params = %{
        "from" => "sender@example.com",
        "to" => "receiver@example.com",
        "body" => "Email body",
        "attachments" => [],
        "timestamp" => "not-a-date"
      }

      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 422)
      assert response["error"] =~ "invalid_timestamp"
    end

    test "rejects email with missing required fields", %{conn: conn} do
      params = %{
        "from" => "sender@example.com",
        "body" => "Email body"
      }

      conn = post(conn, ~p"/api/messages/email", params)

      # Should get a bad request response
      assert conn.status in [400, 422]
    end
  end

  describe "edge cases" do
    test "handles international phone numbers correctly", %{conn: conn} do
      params = %{
        "from" => "+447911123456",
        "to" => "+61412345678",
        "type" => "sms",
        "body" => "International SMS",
        "attachments" => [],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/sms", params)

      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "+447911123456"
      assert message.to == "+61412345678"
    end

    test "handles complex email addresses", %{conn: conn} do
      params = %{
        "from" => "user+tag@example.co.uk",
        "to" => "another.user@subdomain.example.com",
        "body" => "Email body",
        "attachments" => [],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "user+tag@example.co.uk"
      assert message.to == "another.user@subdomain.example.com"
    end

    test "normalizes email addresses to lowercase", %{conn: conn} do
      params = %{
        "from" => "Sender@Example.COM",
        "to" => "Receiver@Example.COM",
        "body" => "Email body",
        "attachments" => [],
        "timestamp" => now()
      }

      conn = post(conn, ~p"/api/messages/email", params)

      assert response = json_response(conn, 202)

      message = Repo.get(Message, response["id"])
      assert message.from == "sender@example.com"
      assert message.to == "receiver@example.com"
    end
  end
end
