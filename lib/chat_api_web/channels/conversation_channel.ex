defmodule ChatApiWeb.ConversationChannel do
  use ChatApiWeb, :channel

  alias ChatApiWeb.{SystemChannel, UserSocket}
  alias ChatApi.{Chat, Serializer, Pagination}

  @impl true
  def join("conversation:" <> conversation_id, payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      case Chat.get_conversation_details(conversation_id, socket.assigns.user_id) do
        {:error, reason} ->
          {:error, reason}

        {:ok,
         %{
           conversation: conversation,
           read_times: read_times,
           messages: messages,
           private_key: private_key,
           public_keys: public_keys
         }} ->
          pub_keys =
            public_keys
            |> Serializer.serialize()
            |> Enum.reduce(%{}, fn key, acc -> Map.put(acc, key.user_id, key) end)

          data = %{
            "conversation" => Serializer.serialize(conversation),
            "users" => Serializer.serialize(conversation.users),
            "messages" => Serializer.serialize_all(messages, Pagination.default_page_size()),
            "read_times" => read_times,
            "public_keys" => pub_keys,
            "private_key" => Serializer.serialize(private_key)
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
      "user_id" => socket.assigns.user_id
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

  def handle_in("leave_conversation", payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      case Chat.leave_conversation(socket.assigns.conversation_id, socket.assigns.user_id) do
        {:error, error} ->
          {:reply, {:error, error}, socket}

        :ok ->
          broadcast!(socket, "leave_conversation", %{
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
    %{"token" => token, "encrypted_messages" => encrypted_messages} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.send_message(
             socket.assigns.conversation_id,
             socket.assigns.user_id,
             encrypted_messages
           ) do
        {:error, error} ->
          {:reply, {:error, error}, socket}

        {:ok, messages} ->
          broadcast_messages_to_users(messages, socket.assigns.user_id, "new_message")

          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("start_typing", payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      broadcast!(socket, "start_typing", %{
        "user_id" => socket.assigns.user_id
      })

      {:noreply, socket}
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("finish_typing", payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      broadcast!(socket, "finish_typing", %{
        "user_id" => socket.assigns.user_id
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
    %{
      "token" => token,
      "message_group_id" => message_group_id,
      "encrypted_messages" => encrypted_messages
    } = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.update_message(message_group_id, socket.assigns.user_id, encrypted_messages) do
        {:error, error} ->
          {:reply, {:error, error}, socket}

        {:ok, messages} ->
          broadcast_messages_to_users(messages, socket.assigns.user_id, "edit_message")

          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("delete_message", payload, socket) do
    %{"token" => token, "message_group_id" => message_group_id} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.delete_message(message_group_id, socket.assigns.user_id) do
        :error ->
          {:reply, {:error, :delete_failed}, socket}

        :ok ->
          broadcast!(socket, "delete_message", %{
            "message_group_id" => message_group_id
          })

          {:noreply, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("modify_conversation", payload, socket) do
    %{"token" => token, "new_members" => new_members, "alias" => new_alias} = payload

    if UserSocket.authorized?(socket, token) do
      new_alias = if new_alias == "", do: nil, else: new_alias

      case Chat.modify_conversation(socket.assigns.conversation_id, new_members, new_alias) do
        {:ok, conversation, user_ids} ->
          SystemChannel.broadcast_new_conversation_to_users(conversation, user_ids)
          {:noreply, socket}

        {:error, error} ->
          {:reply, {:error, error}, socket}
      end
    end
  end

  def handle_in("set_encryption_keys", payload, socket) do
    %{"token" => token, "public_key" => public_key, "private_key" => private_key} = payload

    if UserSocket.authorized?(socket, token) do
      case Chat.set_user_encryption_keys(
             socket.assigns.conversation_id,
             socket.assigns.user_id,
             public_key,
             private_key
           ) do
        {:ok, _} ->
          broadcast!(socket, "set_encryption_keys", %{
            "user_id" => socket.assigns.user_id,
            "public_key" => public_key
          })

          {:noreply, socket}

        {:error, error} ->
          {:reply, {:error, error}, socket}
      end
    end
  end

  @spec broadcast_messages_to_users([Message.t()], String.t(), String.t()) :: :ok
  def broadcast_messages_to_users(messages, sender, event) do
    Enum.map(messages, fn message ->
      broadcast_message_to_user(message, message.recipient_id, sender, event)
    end)

    :ok
  end

  defp broadcast_message_to_user(message, user_id, sender, event) do
    ChatApiWeb.Endpoint.broadcast!(
      "user:#{user_id}",
      event,
      %{"message" => Serializer.serialize(message, sender)}
    )
  end
end
