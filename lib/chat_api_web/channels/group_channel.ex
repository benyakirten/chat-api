defmodule ChatApiWeb.ConversationChannel do
  use ChatApiWeb, :channel

  alias ChatApi.Chat.{Conversation, Message}
  alias ChatApi.Account.User
  alias ChatApiWeb.UserSocket

  @impl true
  def join("group:" <> conversation_id, payload, socket) do
    case UserSocket.get_conversation_data(socket, payload["token"], conversation_id) do
      {:error, reason} -> {:error, reason}
      {:ok, conversation} ->
        data = %{
          "conversation" => Conversation.serialize_conversation(conversation),
          "users" => User.serialize_users(conversation.users),
          "messages" => Message.serialize_messages(conversation.messages)
        }
        {:ok, data, socket}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (conversation:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end
end
