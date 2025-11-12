defmodule MessagingServiceWeb.ConversationControllerTest do
  use MessagingServiceWeb.ConnCase

  alias MessagingService.Messaging

  setup do
    # Create test messages for different conversations
    {:ok, message1} =
      Messaging.create_message(%{
        direction: "inbound",
        type: "sms",
        from: "+15551234567",
        to: "+15559876543",
        body: "Hello from Alice",
        timestamp: ~U[2024-01-01 10:00:00Z]
      })

    {:ok, message2} =
      Messaging.create_message(%{
        direction: "outbound",
        type: "sms",
        from: "+15559876543",
        to: "+15551234567",
        body: "Hi Alice, this is Bob",
        timestamp: ~U[2024-01-01 10:05:00Z]
      })

    {:ok, message3} =
      Messaging.create_message(%{
        direction: "inbound",
        type: "sms",
        from: "+15551234567",
        to: "+15559876543",
        body: "How are you?",
        timestamp: ~U[2024-01-01 10:10:00Z]
      })

    # Different conversation
    {:ok, message4} =
      Messaging.create_message(%{
        direction: "inbound",
        type: "email",
        from: "charlie@example.com",
        to: "david@example.com",
        body: "Hey David, check this out",
        timestamp: ~U[2024-01-01 11:00:00Z]
      })

    {:ok, message5} =
      Messaging.create_message(%{
        direction: "outbound",
        type: "email",
        from: "david@example.com",
        to: "charlie@example.com",
        body: "Thanks Charlie!",
        timestamp: ~U[2024-01-01 11:30:00Z]
      })

    %{
      messages: [message1, message2, message3, message4, message5]
    }
  end

  describe "GET /api/conversations/" do
    test "lists all conversations with metadata", %{conn: conn} do
      conn = get(conn, "/api/conversations/")
      assert %{"conversations" => conversations} = json_response(conn, 200)

      assert length(conversations) == 2

      email_conv =
        Enum.find(conversations, fn conv ->
          Enum.sort([conv["participant1"], conv["participant2"]]) ==
            ["charlie@example.com", "david@example.com"]
        end)

      sms_conv =
        Enum.find(conversations, fn conv ->
          Enum.sort([conv["participant1"], conv["participant2"]]) ==
            ["+15551234567", "+15559876543"]
        end)

      assert email_conv, "Email conversation not found"
      assert sms_conv, "SMS conversation not found"

      assert email_conv["message_count"] == 2
      assert email_conv["latest_message_body"] == "Thanks Charlie!"
      assert email_conv["latest_message_at"]
      assert email_conv["conversation_key"]

      assert sms_conv["message_count"] == 3
      assert sms_conv["latest_message_body"] == "How are you?"
      assert sms_conv["latest_message_at"]
      assert sms_conv["conversation_key"]
    end

    test "returns empty list when no conversations exist", %{conn: conn} do
      Messaging.list_messages() |> Enum.each(&Messaging.delete_message/1)

      conn = get(conn, "/api/conversations/")
      assert %{"conversations" => []} = json_response(conn, 200)
    end

    test "normalizes participants (sorted alphabetically)", %{conn: conn} do
      conn = get(conn, "/api/conversations/")
      assert %{"conversations" => conversations} = json_response(conn, 200)

      Enum.each(conversations, fn conv ->
        assert conv["participant1"] <= conv["participant2"]
      end)
    end
  end

  describe "GET /api/conversations/:id/messages" do
    test "returns messages for a specific conversation", %{conn: conn} do
      conversation_id = "+15551234567::+15559876543"
      conn = get(conn, "/api/conversations/#{conversation_id}/messages")

      assert %{"conversation" => conversation} = json_response(conn, 200)
      assert conversation["participant1"] == "+15551234567"
      assert conversation["participant2"] == "+15559876543"

      messages = conversation["messages"]
      assert length(messages) == 3

      # Messages should be ordered by timestamp ascending
      assert Enum.at(messages, 0)["body"] == "Hello from Alice"
      assert Enum.at(messages, 1)["body"] == "Hi Alice, this is Bob"
      assert Enum.at(messages, 2)["body"] == "How are you?"

      first_message = Enum.at(messages, 0)
      assert first_message["direction"] == "inbound"
      assert first_message["type"] == "sms"
      assert first_message["from"] == "+15551234567"
      assert first_message["to"] == "+15559876543"
      assert first_message["id"]
      assert first_message["timestamp"]
    end

    test "works with reversed participant order", %{conn: conn} do
      # Request with participants in reverse order
      conversation_id = "+15559876543::+15551234567"
      conn = get(conn, "/api/conversations/#{conversation_id}/messages")

      assert %{"conversation" => conversation} = json_response(conn, 200)

      assert conversation["participant1"] == "+15551234567"
      assert conversation["participant2"] == "+15559876543"

      messages = conversation["messages"]
      assert length(messages) == 3
    end

    test "returns messages for email conversation", %{conn: conn} do
      conversation_id = "charlie@example.com::david@example.com"
      conn = get(conn, "/api/conversations/#{conversation_id}/messages")

      assert %{"conversation" => conversation} = json_response(conn, 200)
      assert conversation["participant1"] == "charlie@example.com"
      assert conversation["participant2"] == "david@example.com"

      messages = conversation["messages"]
      assert length(messages) == 2
      assert Enum.at(messages, 0)["type"] == "email"
      assert Enum.at(messages, 1)["type"] == "email"
    end

    test "returns empty messages for non-existent conversation", %{conn: conn} do
      conversation_id = "unknown@example.com::nobody@example.com"
      conn = get(conn, "/api/conversations/#{conversation_id}/messages")

      assert %{"conversation" => conversation} = json_response(conn, 200)
      assert conversation["messages"] == []
    end

    test "returns error for invalid conversation ID format", %{conn: conn} do
      # Missing separator
      conn = get(conn, "/api/conversations/invalid-format/messages")

      assert %{"error" => error} = json_response(conn, 400)
      assert error == "Invalid conversation ID format. Use 'participant1::participant2'"
    end

    test "returns error for conversation ID with too many parts", %{conn: conn} do
      conversation_id = "part1::part2::part3"
      conn = get(conn, "/api/conversations/#{conversation_id}/messages")

      assert %{"error" => error} = json_response(conn, 400)
      assert error == "Invalid conversation ID format. Use 'participant1::participant2'"
    end

    test "returns error for conversation ID with empty participants", %{conn: conn} do
      conversation_id = "::"
      conn = get(conn, "/api/conversations/#{conversation_id}/messages")

      assert %{"error" => error} = json_response(conn, 400)
      assert error == "Invalid conversation ID format. Use 'participant1::participant2'"
    end

    test "handles special characters in participant identifiers", %{conn: conn} do
      # Create a conversation with special characters
      {:ok, _msg} =
        Messaging.create_message(%{
          direction: "inbound",
          type: "email",
          from: "user+tag@example.com",
          to: "admin@example.com",
          body: "Test message",
          timestamp: ~U[2024-01-02 10:00:00Z]
        })

      conversation_id = URI.encode("admin@example.com::user+tag@example.com")
      conn = get(conn, "/api/conversations/#{conversation_id}/messages")

      assert %{"conversation" => conversation} = json_response(conn, 200)
      assert conversation["participant1"] == "admin@example.com"
      assert conversation["participant2"] == "user+tag@example.com"
      assert length(conversation["messages"]) == 1
    end
  end

  describe "conversation integration" do
    test "index and show work together", %{conn: conn} do
      conn1 = get(conn, "/api/conversations/")
      assert %{"conversations" => conversations} = json_response(conn1, 200)
      assert length(conversations) == 2

      # Pick first conversation and use its conversation_key
      first_conv = Enum.at(conversations, 0)
      conversation_id = URI.encode(first_conv["conversation_key"])

      conn2 = get(conn, "/api/conversations/#{conversation_id}/messages")
      assert %{"conversation" => conversation} = json_response(conn2, 200)

      assert length(conversation["messages"]) == first_conv["message_count"]
    end

    test "conversations are updated when new messages are added", %{conn: conn} do
      conn1 = get(conn, "/api/conversations/")
      initial_conversations = json_response(conn1, 200)["conversations"]
      initial_count = length(initial_conversations)

      {:ok, _new_message} =
        Messaging.create_message(%{
          direction: "outbound",
          type: "sms",
          from: "+15559876543",
          to: "+15551234567",
          body: "Another message",
          timestamp: ~U[2024-01-01 10:15:00Z]
        })

      conn2 = get(conn, "/api/conversations/")
      updated_conversations = json_response(conn2, 200)["conversations"]

      # Should still have same number of conversations
      assert length(updated_conversations) == initial_count

      # Find the SMS conversation by matching both participants
      sms_conv =
        Enum.find(updated_conversations, fn conv ->
          Enum.sort([conv["participant1"], conv["participant2"]]) ==
            ["+15551234567", "+15559876543"]
        end)

      assert sms_conv, "SMS conversation not found"

      # Message count should have increased
      assert sms_conv["message_count"] == 4

      {:ok, _new_conv_message} =
        Messaging.create_message(%{
          direction: "inbound",
          type: "sms",
          from: "+15551111111",
          to: "+15552222222",
          body: "New conversation",
          timestamp: ~U[2024-01-02 12:00:00Z]
        })

      conn3 = get(conn, "/api/conversations/")
      final_conversations = json_response(conn3, 200)["conversations"]

      assert length(final_conversations) == initial_count + 1
    end
  end
end
