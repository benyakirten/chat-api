defmodule ChatApiWeb.ApiController do
  alias ChatApi.Pagination
  alias ChatApi.Chat
  use ChatApiWeb, :controller

  def get_messages(
        %Plug.Conn{
          assigns: %{user_id: user_id},
          query_params: %{"conversation_id" => conversation_id}
        } = conn,
        _
      ) do
    page_token = Map.get(conn.query_params, "page_token", "")
    page_size = Map.get(conn.query_params, "page_size", Pagination.default_page_size())

    with {:ok, messages, page_size} <-
           Chat.paginate_more_messages(conversation_id, user_id, page_token, page_size),
         do: render(conn, :paginate_messages, %{messages: messages, page_size: page_size})
  end
end
