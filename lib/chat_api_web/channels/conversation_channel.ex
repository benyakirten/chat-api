defmodule ChatApiWeb.ConversationChannel do
  use ChatApiWeb, :channel

  alias ChatApiWeb.UserSocket
  alias ChatApi.Chat
  alias ChatApi.Serializer

  @impl true
  def join("conversation:" <> conversation_id, payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      case Chat.get_conversation_details(conversation_id, socket.assigns.user_id) do
        {:error, reason} ->
          {:error, reason}

        {:ok, conversation, read_times} ->
          data = %{
            "conversation" => Serializer.serialize(conversation),
            "users" => Serializer.serialize(conversation.users),
            "messages" => Serializer.serialize(conversation.messages),
            "read_times" => read_times
          }

          {:ok, data, assign(socket, :conversation_id, conversation_id)}
      end
    else
      {:error, :unauthorized}
    end
  end

  @impl true
  def terminate({:shutdown, _}, socket) do
    broadcast!(socket, "finish_typing", %{
      "user_id" => socket.assigns.user_id,
      "conversation_id" => socket.assigns.conversation_id
    })

    :ok
  end

  @impl true
  def handle_in("change_alias", payload, socket) do
    %{"token" => token, "alias" => new_alias} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.change_conversation_alias(socket.assigns.conversation_id, new_alias) do
        {:error, reason} ->
          {:reply, {:error, reason}, socket}

        {:ok, conversation} ->
          broadcast!(socket, "update_alias", %{
            "conversation" => Serializer.serialize(conversation)
          })

          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("leave_channel", payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      case Chat.leave_conversation(socket.assigns.conversation_id, socket.assigns.user_id) do
        {:error, error} ->
          {:reply, {:error, error}, socket}

        :ok ->
          broadcast!(socket, "leave_channel", %{
            user_id: socket.assigns.user_id
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
          msg = %{"message" => Serializer.serialize(message)}
          broadcast!(socket, "new_message", msg)
          {:reply, {:ok, msg}, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("start_typing", payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      broadcast!(socket, "start_typing", %{
        "user_id" => socket.assigns.user_id,
        "conversation_id" => socket.assigns.conversation_id
      })

      {:noreply, socket}
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("finish_typing", payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      broadcast!(socket, "finish_typing", %{
        "user_id" => socket.assigns.user_id,
        "conversation_id" => socket.assigns.conversation_id
      })

      {:noreply, socket}
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("read_conversation", payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      case Chat.update_read_time(socket.assigns.conversation_id, socket.assigns.user_id) do
        :error ->
          {:reply, {:error, :read_update_failed}, socket}

        :ok ->
          broadcast!(socket, "read_conversation", %{"user_id" => socket.assigns.user_id})
          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("edit_message", payload, socket) do
    %{"token" => token, "message_id" => message_id, "content" => content} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.update_message(message_id, socket.assigns.user_id, content) do
        {:error, error} ->
          {:reply, {:error, error}, socket}

        {:ok, message} ->
          broadcast!(socket, "update_message", %{
            "message" => Serializer.serialize(message),
            "conversation_id" => socket.assigns.conversation_id
          })

          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("delete_message", payload, socket) do
    %{"token" => token, "message_id" => message_id} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.delete_message(message_id, socket.assigns.user_id) do
        :error ->
          {:reply, {:error, :delete_failed}, socket}

        :ok ->
          broadcast!(socket, "delete_message", %{
            "message_id" => message_id,
            "conversation_id" => socket.assigns.conversation_id
          })

          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end
end
