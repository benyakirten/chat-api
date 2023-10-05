defmodule ChatApiWeb.UserChannel do
  alias ChatApiWeb.UserSocket
  use ChatApiWeb, :channel

  @impl true
  def join("user:" <> id, payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) and id == socket.assigns.user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("new_conversation", payload, socket) do
    {:reply, payload, socket}
  end
end
