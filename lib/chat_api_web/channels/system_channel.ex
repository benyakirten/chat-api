defmodule ChatApiWeb.SystemChannel do
  alias ChatApiWeb.UserSocket
  alias ChatApiWeb.Presence
  alias ChatApi.{Account, Serializer}
  use ChatApiWeb, :channel

  defp add_user_id_to_presence(socket),
    do:
      Presence.track(socket, socket.assigns.user_id, %{
        online_at: inspect(System.system_time(:second))
      })

  defp remove_user_id_from_presence(socket), do: Presence.untrack(socket, socket.assigns.user_id)

  @impl true
  def join("system:general", params, socket) do
    if UserSocket.authorized?(socket, params["token"]) do
      send(self(), :track_user)
      {:ok, assign(socket, :hidden, params["hidden"] || false)}
    else
      {:error, %{reason: "Invalid Token"}}
    end
  end

  @impl true
  def terminate({:shutdown, _}, socket) do
    broadcast!(socket, "user_disconnect", %{"user_id" => socket.assigns.user_id})
    :ok
  end

  @impl true
  def handle_info(:track_user, socket) do
    if socket.assigns.hidden do
      :ok = remove_user_id_from_presence(socket)
    else
      {:ok, _} = add_user_id_to_presence(socket)
    end

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update_hidden_state, socket) do
    Account.update_profile_by_user_id(socket.assigns.user_id, %{hidden: socket.assigns.hidden})
    send(self(), :track_user)
    {:noreply, socket}
  end

  @impl true
  def handle_in("set_hidden", payload, socket) do
    %{"hidden" => hidden, "token" => token} = payload

    if UserSocket.authorized?(socket, token) do
      send(self(), :update_hidden_state)
      {:noreply, assign(socket, :hidden, hidden)}
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  @impl true
  def handle_in("set_display_name", payload, socket) do
    %{"token" => token, "display_name" => display_name} = payload

    if UserSocket.authorized?(socket, token) do
      with user when not is_nil(user) <- Account.get_user(socket.assigns.user_id) do
        case Account.update_display_name(user, display_name) do
          {:ok, updated_user} ->
            broadcast!(socket, "update_display_name", %{
              "user_id" => socket.assigns.user_id,
              "display_name" => display_name
            })

            {:noreply, socket}

          {:error, error} ->
            {:reply, {:error, error}, socket}
        end
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("start_conversation", payload, socket) do
    %{
      "user_ids" => user_ids,
      "private" => private,
      "message" => first_message_content,
      "token" => token
    } = payload

    conversation_alias = Map.get(payload, "alias", nil)

    if UserSocket.authorized?(socket, token) do
      case ChatApi.Chat.start_conversation(
             user_ids,
             private,
             first_message_content,
             socket.assigns.user_id,
             conversation_alias
           ) do
        {:error, reason} ->
          {:reply, {:error, reason}, socket}

        {:ok, conversation} ->
          # Retrieve new users to users
          broadcast_new_conversation_to_users(conversation, user_ids)
          {:reply, {:ok, conversation.id}, socket}
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def broadcast_new_conversation_to_users(conversation, user_ids) do
    for user_id <- user_ids do
      ChatApiWeb.Endpoint.broadcast(
        "user:#{user_id}",
        "new_conversation",
        %{
          "conversation" => Serializer.serialize(conversation),
          "user_ids" => user_ids
        }
      )
    end
  end
end
