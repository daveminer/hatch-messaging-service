defmodule MessagingService.Messaging.Providers.SMSTest do
  use ExUnit.Case, async: true

  alias MessagingService.Messaging.Providers.SMS
  alias MessagingService.Messaging.Message

  # Helper to create a timestamp without microseconds
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  describe "name/0" do
    test "returns the provider name" do
      assert SMS.name() == :sms
    end
  end

  describe "send_outbound/1 - SMS" do
    test "successfully sends an outbound SMS message" do
      payload = %{
        "direction" => "outbound",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "Test SMS message",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.send_outbound(payload)
      assert message.direction == "outbound"
      assert message.type == "sms"
      assert message.from == "+15551234567"
      assert message.to == "+15559876543"
      assert message.body == "Test SMS message"
      assert message.attachments == []
      assert message.timestamp == payload["timestamp"]
    end

    test "handles empty body" do
      payload = %{
        "direction" => "outbound",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.send_outbound(payload)
      assert message.body == ""
    end

    test "returns error for invalid type" do
      payload = %{
        "direction" => "outbound",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "email",
        "body" => "Wrong type",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:error, {:invalid_sms_outbound_payload, "email"}} = SMS.send_outbound(payload)
    end
  end

  describe "send_outbound/1 - MMS" do
    test "successfully sends an outbound MMS message with attachments" do
      payload = %{
        "direction" => "outbound",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "mms",
        "body" => "Check out this image!",
        "attachments" => ["https://example.com/image.jpg", "https://example.com/video.mp4"],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.send_outbound(payload)
      assert message.type == "sms"
      assert message.body == "Check out this image!"

      assert message.attachments == [
               "https://example.com/image.jpg",
               "https://example.com/video.mp4"
             ]
    end

    test "handles MMS without attachments" do
      payload = %{
        "direction" => "outbound",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "mms",
        "body" => "MMS without attachments",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.send_outbound(payload)
      assert message.type == "sms"
      assert message.attachments == []
    end
  end

  describe "handle_inbound/1 - SMS" do
    test "successfully handles an inbound SMS message" do
      payload = %{
        "from" => "+15559876543",
        "to" => "+15551234567",
        "type" => "sms",
        "messaging_provider_id" => "twilio-msg-123",
        "body" => "Reply message",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.handle_inbound(payload)
      assert message.direction == "inbound"
      assert message.type == "sms"
      assert message.from == "+15559876543"
      assert message.to == "+15551234567"
      assert message.body == "Reply message"
      assert message.attachments == []
      assert message.metadata[:messaging_provider_id] == "twilio-msg-123"
    end

    test "handles empty body in inbound SMS" do
      payload = %{
        "from" => "+15559876543",
        "to" => "+15551234567",
        "type" => "sms",
        "messaging_provider_id" => "twilio-msg-456",
        "body" => nil,
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.handle_inbound(payload)
      assert message.body == ""
    end

    test "handles nil attachments in inbound SMS" do
      payload = %{
        "from" => "+15559876543",
        "to" => "+15551234567",
        "type" => "sms",
        "messaging_provider_id" => "twilio-msg-789",
        "body" => "Test",
        "attachments" => nil,
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.handle_inbound(payload)
      assert message.attachments == []
    end
  end

  describe "handle_inbound/1 - MMS" do
    test "successfully handles an inbound MMS message with attachments" do
      payload = %{
        "from" => "+15559876543",
        "to" => "+15551234567",
        "type" => "mms",
        "messaging_provider_id" => "twilio-mms-123",
        "body" => "Check this out",
        "attachments" => ["https://media.twilio.com/image1.jpg"],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.handle_inbound(payload)
      assert message.direction == "inbound"
      assert message.type == "mms"
      assert message.from == "+15559876543"
      assert message.to == "+15551234567"
      assert message.body == "Check this out"
      assert message.attachments == ["https://media.twilio.com/image1.jpg"]
      assert message.metadata[:messaging_provider_id] == "twilio-mms-123"
    end

    test "handles MMS with multiple attachments" do
      payload = %{
        "from" => "+15559876543",
        "to" => "+15551234567",
        "type" => "mms",
        "messaging_provider_id" => "twilio-mms-456",
        "body" => "Multiple files",
        "attachments" => [
          "https://media.twilio.com/image1.jpg",
          "https://media.twilio.com/video1.mp4"
        ],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = SMS.handle_inbound(payload)
      assert length(message.attachments) == 2
    end
  end

  describe "handle_inbound/1 - error cases" do
    test "returns error for invalid type" do
      payload = %{
        "from" => "+15559876543",
        "to" => "+15551234567",
        "type" => "email",
        "messaging_provider_id" => "wrong-123",
        "body" => "Wrong type",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:error, :invalid_sms_webhook_payload} = SMS.handle_inbound(payload)
    end
  end

  describe "timestamp handling" do
    test "preserves provided timestamp in outbound" do
      timestamp = ~U[2024-11-10 15:30:00Z]

      payload = %{
        "direction" => "outbound",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "type" => "sms",
        "body" => "Timestamped message",
        "attachments" => [],
        "timestamp" => timestamp
      }

      assert {:ok, %Message{} = message} = SMS.send_outbound(payload)
      assert message.timestamp == timestamp
    end

    test "preserves provided timestamp in inbound" do
      timestamp = ~U[2024-11-10 15:30:00Z]

      payload = %{
        "from" => "+15559876543",
        "to" => "+15551234567",
        "type" => "sms",
        "messaging_provider_id" => "test-123",
        "body" => "Timestamped reply",
        "attachments" => [],
        "timestamp" => timestamp
      }

      assert {:ok, %Message{} = message} = SMS.handle_inbound(payload)
      assert message.timestamp == timestamp
    end
  end
end
