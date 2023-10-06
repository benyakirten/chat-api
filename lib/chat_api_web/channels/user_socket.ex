defmodule ChatApiWeb.UserSocket do
  alias ChatApi.Serializer
  alias ChatApi.Token
  alias ChatApi.Chat
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

  defp get_conversation_data(socket, token, conversation_id) do
    if authorized?(socket, token) do
      Chat.get_conversation_details(conversation_id, socket.assigns.user_id)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Verify the user is part of the conversation. If so, retrieve the conversation,
  the users and all messages (in descending order).
  """
  def handle_conversation_channel_join(conversation_id, payload, socket) do
    case get_conversation_data(socket, payload["token"], conversation_id) do
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
  end
end
