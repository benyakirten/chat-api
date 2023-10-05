defmodule ChatApiWeb.SystemChannel do
  alias ChatApiWeb.UserSocket
  alias ChatApiWeb.Presence
  alias ChatApi.Account
  use ChatApiWeb, :channel

  defp add_user_id_to_presence(socket), do: Presence.track(socket, socket.assigns.user_id, %{
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
    if UserSocket.authorized?(socket, payload["token"]) do
      send(self(), :update_hidden_state)
      {:noreply, assign(socket, :hidden, payload["hidden"])}
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  @impl true
  def handle_in("set_display_name", payload, socket) do
    # TODO: Make this only one database transaction
    if UserSocket.authorized?(socket, payload["token"]) do
      display_name = payload["display_name"]

      with user when not is_nil(user) <- Account.get_user(socket.assigns.user_id) do
        if user.display_name == display_name do
          {:reply, {:error, :display_name_unchanged}, socket}
        else
          case Account.update_display_name(user, display_name) do
            {:ok, updated_user} ->
              broadcast!(socket, "update_display_name", %{
                user_id: socket.assigns.user_id,
                display_name: updated_user.display_name
              })
              {:noreply, socket}
            error -> {:reply, {:error, error}, socket}
          end
        end
      end
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end

  def handle_in("start_conversation", payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      # TODO: Actually call the ChatApi.Chat functions
      ChatApiWeb.Endpoint.broadcast("user:#{socket.assigns.user_id}", "new_conversation", %{"this" => "works?"})
      {:noreply, socket}
    else
      {:reply, {:error, :invalid_token}, socket}
    end
  end
end
