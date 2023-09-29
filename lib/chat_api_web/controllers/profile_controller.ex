defmodule ChatApiWeb.ProfileController do
  use ChatApiWeb, :controller

  # alias ChatApi.Account
  # alias ChatApi.Account.User

  action_fallback ChatApiWeb.FallbackController

  def update_password(conn, opts) do
    IO.inspect(conn)
    IO.inspect(opts)
    # render(conn, :update_password, [user_id: user_id])
  end
end
