defmodule MessagingService.Messaging.DispatcherTest do
  use MessagingService.DataCase, async: true

  alias MessagingService.Messaging.Dispatcher
  alias MessagingService.Messaging.Message
  alias MessagingService.Repo

  # Helper to create a timestamp without microseconds
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  describe "dispatch/1 - outbound SMS" do
    test "successfully dispatches an outbound SMS message" do
      params = %{
        "direction" => "outbound",
        "type" => "sms",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "body" => "Test SMS message",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Dispatcher.dispatch(params)
      assert message.direction == "outbound"
      assert message.type == "sms"
      assert message.from == "+15551234567"
      assert message.to == "+15559876543"
      assert message.body == "Test SMS message"
      assert message.id != nil

      # Verify it was persisted
      assert Repo.get(Message, message.id)
    end

    test "successfully dispatches an outbound MMS message" do
      params = %{
        "direction" => "outbound",
        "type" => "mms",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "body" => "Test MMS message",
        "attachments" => ["https://example.com/image.jpg"],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Dispatcher.dispatch(params)
      assert message.type == "sms"
      assert message.attachments == ["https://example.com/image.jpg"]
    end
  end

  describe "dispatch/1 - outbound email" do
    test "successfully dispatches an outbound email message" do
      params = %{
        "direction" => "outbound",
        "type" => "email",
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "body" => "<p>Test email body</p>",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Dispatcher.dispatch(params)
      assert message.direction == "outbound"
      assert message.type == "email"
      assert message.from == "sender@example.com"
      assert message.to == "recipient@example.com"
      assert message.body == "<p>Test email body</p>"
      assert message.id != nil
    end

    test "handles attachments for outbound email" do
      params = %{
        "direction" => "outbound",
        "type" => "email",
        "from" => "sender@example.com",
        "to" => "recipient@example.com",
        "body" => "Email with attachments",
        "attachments" => ["file1.pdf", "file2.jpg"],
        "timestamp" => now()
      }

      assert {:ok, %Message{} = message} = Dispatcher.dispatch(params)
      assert message.attachments == ["file1.pdf", "file2.jpg"]
    end
  end

  describe "dispatch/1 - inbound SMS" do
    test "successfully handles an inbound SMS message" do
      params = %{
        "direction" => "inbound",
        "type" => "sms",
        "from" => "+15559876543",
        "to" => "+15551234567",
        "body" => "Reply message",
        "attachments" => [],
        "timestamp" => now(),
        "messaging_provider_id" => "twilio-msg-123"
      }

      assert {:ok, %Message{} = message} = Dispatcher.dispatch(params)
      assert message.direction == "inbound"
      assert message.type == "sms"
      assert message.from == "+15559876543"
      assert message.to == "+15551234567"
      assert message.body == "Reply message"
      assert message.metadata[:messaging_provider_id] == "twilio-msg-123"
    end

    test "successfully handles an inbound MMS message" do
      params = %{
        "direction" => "inbound",
        "type" => "mms",
        "from" => "+15559876543",
        "to" => "+15551234567",
        "body" => "MMS reply",
        "attachments" => ["https://media.url/image.jpg"],
        "timestamp" => now(),
        "messaging_provider_id" => "twilio-msg-456"
      }

      assert {:ok, %Message{} = message} = Dispatcher.dispatch(params)
      assert message.type == "mms"
      assert message.attachments == ["https://media.url/image.jpg"]
    end
  end

  describe "dispatch/1 - inbound email" do
    test "successfully handles an inbound email message" do
      params = %{
        "direction" => "inbound",
        "type" => "email",
        "from" => "external@example.com",
        "to" => "support@myapp.com",
        "body" => "<p>Customer inquiry</p>",
        "timestamp" => now(),
        "xillio_id" => "email-webhook-789"
      }

      assert {:ok, %Message{} = message} = Dispatcher.dispatch(params)
      assert message.direction == "inbound"
      assert message.type == "email"
      assert message.from == "external@example.com"
      assert message.to == "support@myapp.com"
      assert message.body == "<p>Customer inquiry</p>"
    end
  end

  describe "dispatch/1 - error cases" do
    test "returns error for invalid direction" do
      params = %{
        "direction" => "sideways",
        "type" => "sms",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "body" => "Test",
        "timestamp" => now()
      }

      assert {:error, {:invalid_direction, "sideways"}} = Dispatcher.dispatch(params)
    end

    test "returns error for unknown message type" do
      params = %{
        "direction" => "outbound",
        "type" => "carrier_pigeon",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "body" => "Test"
      }

      assert {:error, {:unknown_provider_type, "carrier_pigeon"}} = Dispatcher.dispatch(params)
    end

    test "returns error for invalid outbound SMS payload" do
      params = %{
        "direction" => "outbound",
        "type" => "telegram"
      }

      assert {:error, {:unknown_provider_type, "telegram"}} = Dispatcher.dispatch(params)
    end
  end

  describe "dispatch/1 - database persistence" do
    test "persisted message includes all expected fields" do
      params = %{
        "direction" => "outbound",
        "type" => "sms",
        "from" => "+15551111111",
        "to" => "+15552222222",
        "body" => "Persistence test",
        "attachments" => [],
        "timestamp" => ~U[2024-11-10 12:00:00Z],
        "metadata" => %{"custom" => "data"}
      }

      assert {:ok, message} = Dispatcher.dispatch(params)

      # Reload from database to ensure all fields were saved
      reloaded = Repo.get!(Message, message.id)

      assert reloaded.direction == "outbound"
      assert reloaded.type == "sms"
      assert reloaded.from == "+15551111111"
      assert reloaded.to == "+15552222222"
      assert reloaded.body == "Persistence test"
      assert reloaded.attachments == []
      assert reloaded.timestamp == ~U[2024-11-10 12:00:00Z]
      assert reloaded.inserted_at != nil
      assert reloaded.updated_at != nil
    end

    test "creates conversation_key correctly" do
      params = %{
        "direction" => "outbound",
        "type" => "sms",
        "from" => "+15551111111",
        "to" => "+15552222222",
        "body" => "Test",
        "attachments" => [],
        "timestamp" => now()
      }

      assert {:ok, message} = Dispatcher.dispatch(params)

      # Query the database to check conversation_key
      result =
        Repo.query!(
          "SELECT conversation_key FROM messages WHERE id = $1",
          [Ecto.UUID.dump!(message.id)]
        )

      [[conversation_key]] = result.rows
      assert conversation_key == "+15551111111::+15552222222"
    end

    test "conversation_key is direction-agnostic" do
      outbound_params = %{
        "direction" => "outbound",
        "type" => "sms",
        "from" => "+15551111111",
        "to" => "+15552222222",
        "body" => "Outbound",
        "attachments" => [],
        "timestamp" => now()
      }

      inbound_params = %{
        "direction" => "inbound",
        "type" => "sms",
        "from" => "+15552222222",
        "to" => "+15551111111",
        "body" => "Inbound",
        "attachments" => [],
        "timestamp" => now(),
        "messaging_provider_id" => "test-123"
      }

      assert {:ok, msg1} = Dispatcher.dispatch(outbound_params)
      assert {:ok, msg2} = Dispatcher.dispatch(inbound_params)

      # Get conversation keys
      result1 =
        Repo.query!("SELECT conversation_key FROM messages WHERE id = $1", [
          Ecto.UUID.dump!(msg1.id)
        ])

      result2 =
        Repo.query!("SELECT conversation_key FROM messages WHERE id = $1", [
          Ecto.UUID.dump!(msg2.id)
        ])

      [[key1]] = result1.rows
      [[key2]] = result2.rows

      # Both should have the same conversation key
      assert key1 == key2
    end
  end

  describe "dispatch/1 - timestamp handling" do
    test "uses provided timestamp" do
      timestamp = ~U[2024-01-15 10:30:00Z]

      params = %{
        "direction" => "outbound",
        "type" => "sms",
        "from" => "+15551234567",
        "to" => "+15559876543",
        "body" => "Timestamped message",
        "attachments" => [],
        "timestamp" => timestamp
      }

      assert {:ok, message} = Dispatcher.dispatch(params)
      assert message.timestamp == timestamp
    end
  end
end
