defmodule ChatApiWeb.ApiController do
  alias ChatApi.Chat
  use ChatApiWeb, :controller

  def get_messages(
        %Plug.Conn{
          assigns: %{user_id: user_id},
          query_params: %{"conversation_id" => conversation_id, "page_token" => page_token}
        } = conn,
        _
      ) do
    with {:ok, messages, page_size} <-
           Chat.paginate_more_messages(conversation_id, user_id, page_token) do
      # Success
      conn
    end

    # Properly render error case
  end
end
