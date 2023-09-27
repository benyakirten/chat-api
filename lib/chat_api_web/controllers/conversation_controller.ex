defmodule ChatApiWeb.ConversationController do
  use ChatApiWeb, :controller

  alias ChatApi.Chat
  alias ChatApi.Chat.Conversation

  action_fallback ChatApiWeb.FallbackController

  def index(conn, _params) do
    conversations = Chat.list_conversations()
    render(conn, :index, conversations: conversations)
  end

  def create(conn, %{"conversation" => conversation_params}) do
    with {:ok, %Conversation{} = conversation} <- Chat.create_conversation(conversation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/conversations/#{conversation}")
      |> render(:show, conversation: conversation)
    end
  end

  def show(conn, %{"id" => id}) do
    conversation = Chat.get_conversation!(id)
    render(conn, :show, conversation: conversation)
  end

  def update(conn, %{"id" => id, "conversation" => conversation_params}) do
    conversation = Chat.get_conversation!(id)

    with {:ok, %Conversation{} = conversation} <-
           Chat.update_conversation(conversation, conversation_params) do
      render(conn, :show, conversation: conversation)
    end
  end

  def delete(conn, %{"id" => id}) do
    conversation = Chat.get_conversation!(id)

    with {:ok, %Conversation{}} <- Chat.delete_conversation(conversation) do
      send_resp(conn, :no_content, "")
    end
  end
end
