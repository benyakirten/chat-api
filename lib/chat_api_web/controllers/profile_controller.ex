defmodule ChatApiWeb.ProfileController do
  use ChatApiWeb, :controller

  # alias ChatApi.Account
  # alias ChatApi.Account.User

  action_fallback ChatApiWeb.FallbackController

  def update_password(%Plug.Conn{assigns: %{user_id: user_id}}, _opts) do
    IO.inspect(user_id)
    # render(conn, :update_password, [user_id: user_id])
  end
end
