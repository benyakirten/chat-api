defmodule ChatApiWeb.UserSocket do
  alias ChatApi.Token
  use Phoenix.Socket

  channel "system:*", ChatApiWeb.SystemChannel
  channel "conversation:*", ChatApiWeb.ConversationChannel
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
end
