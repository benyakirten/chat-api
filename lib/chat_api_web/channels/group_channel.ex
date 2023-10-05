defmodule ChatApiWeb.ConversationChannel do
  use ChatApiWeb, :channel

  alias ChatApiWeb.UserSocket
  alias ChatApi.Chat
  alias ChatApi.Chat.{Conversation, Message}

  @impl true
  def join("group:" <> conversation_id, payload, socket) do
    UserSocket.handle_conversation_channel_join(conversation_id, payload, socket)
  end

  @impl true
  def handle_in("change_alias", payload, socket) do
    %{"token" => token, "alias" => new_alias} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.change_conversation_alias(socket.assigns.conversation_id, new_alias) do
        {:error, reason} ->
          {:reply, {:error, reason}, socket}

        {:ok, conversation} ->
          broadcast!(socket, "update_conversation_name", %{
            "conversation" => Conversation.serialize(conversation)
          })

          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  @impl true
  def handle_in("send_message", payload, socket) do
    %{"token" => token, "content" => content} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.send_message(socket.assigns.conversation_id, socket.assigns.user_id, content) do
        {:error, error} ->
          {:reply, {:error, error}, socket}

        {:ok, message} ->
          broadcast!(socket, "new_message", %{"message" => Message.serialize(message)})
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end
end
