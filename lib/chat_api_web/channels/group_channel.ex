defmodule ChatApiWeb.ConversationChannel do
  use ChatApiWeb, :channel

  alias ChatApiWeb.UserSocket

  @impl true
  def join("group:" <> conversation_id, payload, socket) do
    UserSocket.handle_conversation_channel_join(conversation_id, payload, socket)
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
