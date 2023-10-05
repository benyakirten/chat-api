defmodule ChatApiWeb.UserChannel do
  alias ChatApiWeb.UserSocket
  use ChatApiWeb, :channel

  @impl true
  def join("user:" <> _id, payload, socket) do
    if UserSocket.authorized?(socket, payload["token"]) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (user:lobby).
  @impl true
  def handle_in("new_conversation", payload, socket) do
    {:reply, payload, socket}
  end
end
