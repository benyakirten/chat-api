defmodule ChatApiWeb.PrivateChannel do
  use ChatApiWeb, :channel

  alias ChatApiWeb.UserSocket
  alias ChatApi.Serializer
  alias ChatApi.Chat

  @impl true
  def join("private:" <> conversation_id, payload, socket) do
    UserSocket.handle_conversation_channel_join(conversation_id, payload, socket)
  end

  @impl true
  def handle_in("send_message", payload, socket) do
    %{"token" => token, "content" => content} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.send_message(socket.assigns.conversation_id, socket.assigns.user_id, content) do
        {:error, error} ->
          {:reply, {:error, error}, socket}

        {:ok, message} ->
          broadcast!(socket, "new_message", %{"message" => Serializer.serialize(message)})
          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end
end
