defmodule ChatApiWeb.UserSocket do
  alias ChatApi.Token
  use Phoenix.Socket

  channel "system:*", ChatApiWeb.SystemChannel
  channel "private:*", ChatApiWeb.PrivateChannel
  channel "group:*", ChatApiWeb.GroupChannel
  channel "user:*", ChatApiWeb.UserChannel

  @impl true
  def connect(params, socket, _connect_info) do
    with {:ok, user_id} <- Token.user_id_from_auth_token(params["token"]) do
      {:ok, assign(socket, :user_id, user_id)}
    else
      _ -> :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  def authorized?(socket, token) do
    user_id = socket.assigns.user_id

    with {:ok, parsed_id} <- Token.user_id_from_auth_token(token), true <- parsed_id == user_id do
      true
     else
      _ -> false
     end
  end

  def get_conversation_data(socket, token, conversation_id) do
    if authorized?(socket, token) do
      ChatApi.Chat.get_conversation_details(conversation_id, socket.assigns.user_id)
    else
      {:error, :unauthorized}
    end
  end
end
