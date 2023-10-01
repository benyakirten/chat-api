defmodule ChatApiWeb.SystemChannel do
  alias ChatApiWeb.Presence
  alias ChatApi.Account
  use ChatApiWeb, :channel

  defp add_user_id_to_presence(socket), do: Presence.track(socket, socket.assigns.user_id, %{
    online_at: inspect(System.system_time(:second))
  })
  defp remove_user_id_from_presence(socket), do: Presence.untrack(socket, socket.assigns.user_id)

  @impl true
  def join("system:general", params, socket) do
    send(self(), :track_user)
    {:ok, assign(socket, :hidden, params["hidden"] || false)}
  end

  @impl true
  def handle_info(:track_user, socket) do
    if socket.assigns.hidden do
      {:ok, _} = add_user_id_to_presence(socket)
    else
      :ok = remove_user_id_from_presence(socket)
    end

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_info("update_hidden_state", socket) do
    Account.update_profile_by_user_id(socket.assigns.user_id, %{hidden: socket.assigns.hidden})
    {:noreply, socket}
  end

  def handle_in("set_hidden", payload, socket) do
    send(self(), :update_hidden_state)
    send(self(), :track_user)

    {:noreply, assign(socket, :hidden, payload["hidden"])}
  end

  def handle_in("set_display_name", payload, socket) do
    send(self(), :update_display_name)
    display_name = payload["display_name"]

    with user when not is_nil(user) <- Account.get_user(socket.assigns.user_id) do
      if user.display_name == display_name do
        {:reply, :display_name_unchanged, socket}
      else
        case  Account.update_display_name(user, display_name) do
          {:ok, updated_user} ->
            broadcast!(socket, "update_display_name", %{
              user_id: socket.assigns.user_id,
              display_name: updated_user.display_name
            })
            {:noreply, socket}
          error -> {:reply, error, socket}
        end
      end
    end
  end

  def handle_in("new_msg", payload, socket) do
    broadcast!(socket, "new_msg", %{body: "I AM GLAD YOU SENT A MESSAGE", payload: payload})
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (system:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end
end
