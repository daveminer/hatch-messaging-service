defmodule MessagingService.Messaging.Providers.EmailTest do
  use ExUnit.Case, async: true

  alias MessagingService.Messaging.Providers.Email
  alias MessagingService.Messaging.Message

  # Helper to create a timestamp without microseconds
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  describe "name/0" do
    test "returns the provider name" do
      assert Email.name() == :email
    end
  end

  describe "send_outbound/1" do
    test "successfully sends an outbound email message" do
      payload = %{
        "direction" => "outbound",
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "type" => "email",
        "body" => "<p>HTML email body</p>",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Email.send_outbound(payload)
      assert message.direction == "outbound"
      assert message.type == "email"
      assert message.from == "sender@example.com"
      assert message.to == "recipient@example.com"
      assert message.body == "<p>HTML email body</p>"
      assert message.attachments == []
      assert message.timestamp == payload["timestamp"]
    end

    test "handles email with attachments" do
      payload = %{
        "direction" => "outbound",
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "type" => "email",
        "body" => "<p>Email with attachments</p>",
        "attachments" => ["document.pdf", "spreadsheet.xlsx"],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Email.send_outbound(payload)
      assert message.attachments == ["document.pdf", "spreadsheet.xlsx"]
    end

    test "handles plain text email body" do
      payload = %{
        "direction" => "outbound",
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "type" => "email",
        "body" => "Plain text email body",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Email.send_outbound(payload)
      assert message.body == "Plain text email body"
    end

    test "handles empty body" do
      payload = %{
        "direction" => "outbound",
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "type" => "email",
        "body" => "",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Email.send_outbound(payload)
      assert message.body == ""
    end

    test "returns error for invalid type" do
      payload = %{
        "direction" => "outbound",
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "type" => "sms",
        "body" => "Wrong type",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:error, {:invalid_payload, "sms"}} = Email.send_outbound(payload)
    end
  end

  describe "handle_inbound/1" do
    test "successfully handles an inbound email message" do
      payload = %{
        "from" => "external@example.com",
        "to" => "support@myapp.com",
        "xillio_id" => "email-webhook-123",
        "body" => "<p>Customer inquiry</p>",
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Email.handle_inbound(payload)
      assert message.direction == "inbound"
      assert message.type == "email"
      assert message.from == "external@example.com"
      assert message.to == "support@myapp.com"
      assert message.body == "<p>Customer inquiry</p>"
      assert message.attachments == []
    end

    test "handles empty body in inbound email" do
      payload = %{
        "from" => "external@example.com",
        "to" => "support@myapp.com",
        "xillio_id" => "email-webhook-456",
        "body" => nil,
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Email.handle_inbound(payload)
      assert message.body == ""
    end

    test "handles long HTML email body" do
      long_body = """
      <html>
        <body>
          <h1>Email Subject</h1>
          <p>This is a long email body with lots of content.</p>
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
            <li>Item 3</li>
          </ul>
        </body>
      </html>
      """

      payload = %{
        "from" => "external@example.com",
        "to" => "support@myapp.com",
        "xillio_id" => "email-webhook-789",
        "body" => long_body,
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Email.handle_inbound(payload)
      assert message.body == long_body
    end

    test "always returns empty attachments for inbound email" do
      payload = %{
        "from" => "external@example.com",
        "to" => "support@myapp.com",
        "xillio_id" => "email-webhook-999",
        "body" => "Test",
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Email.handle_inbound(payload)
      # Inbound email provider doesn't handle attachments in current implementation
      assert message.attachments == []
    end

    test "returns error for invalid payload" do
      # Missing required fields
      payload = %{
        "from" => "external@example.com"
      }

      assert {:error, :invalid_email_webhook_payload} = Email.handle_inbound(payload)
    end
  end

  describe "timestamp handling" do
    test "preserves provided timestamp in outbound" do
      timestamp = ~U[2024-11-10 15:30:00Z]

      payload = %{
        "direction" => "outbound",
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "type" => "email",
        "body" => "Timestamped email",
        "attachments" => [],
        "timestamp" => timestamp
      }

      assert {:ok, %Message{} = message} = Email.send_outbound(payload)
      assert message.timestamp == timestamp
    end

    test "preserves provided timestamp in inbound" do
      timestamp = ~U[2024-11-10 15:30:00Z]

      payload = %{
        "from" => "external@example.com",
        "to" => "support@myapp.com",
        "xillio_id" => "email-test-123",
        "body" => "Timestamped reply",
        "timestamp" => timestamp
      }

      assert {:ok, %Message{} = message} = Email.handle_inbound(payload)
      assert message.timestamp == timestamp
    end
  end

  describe "email addresses" do
    test "handles various email address formats in outbound" do
      test_cases = [
        "simple@example.com",
        "with.dots@example.com",
        "with+plus@example.com",
        "with_underscore@example.com"
      ]

      for email <- test_cases do
        payload = %{
          "direction" => "outbound",
          "from" => email,
          "to" => "recipient@example.com",
          "type" => "email",
          "body" => "Test",
          "attachments" => [],
          "timestamp" => now()
        }

        assert {:ok, %Message{} = message} = Email.send_outbound(payload)
        assert message.from == email
      end
    end

    test "handles various email address formats in inbound" do
      test_cases = [
        "external@example.com",
        "customer+tag@example.com",
        "support.team@example.com"
      ]

      for email <- test_cases do
        payload = %{
          "from" => email,
          "to" => "support@myapp.com",
          "xillio_id" => "test-#{:rand.uniform(1000)}",
          "body" => "Test",
          "timestamp" => now()
        }

        assert {:ok, %Message{} = message} = Email.handle_inbound(payload)
        assert message.from == email
      end
    end
  end
end
