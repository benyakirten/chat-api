defmodule ChatApiWeb.ApiController do
  alias ChatApi.Parameters
  alias ChatApi.{Pagination, Chat}
  use ChatApiWeb, :controller

  action_fallback ChatApiWeb.FallbackController

  def get_messages(%Plug.Conn{assigns: %{user_id: user_id}} = conn, _) do
    page_token = Map.get(conn.query_params, "page_token", "")
    page_size = Map.get(conn.query_params, "page_size", Pagination.default_page_size())

    with :ok <- Parameters.list_missing_params(conn.query_params, ["conversation_id"]),
         conversation_id <- Map.get(conn.query_params, "conversation_id"),
         {:ok, messages, page_size} <-
           Chat.paginate_more_messages(conversation_id, user_id, page_token, page_size) do
      render(conn, :paginate_messages, %{messages: messages, page_size: page_size})
    end
  end
end
