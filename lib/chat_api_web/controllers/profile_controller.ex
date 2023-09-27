defmodule ChatApiWeb.ProfileController do
  use ChatApiWeb, :controller

  # alias ChatApi.Account
  # alias ChatApi.Account.User

  action_fallback ChatApiWeb.FallbackController

  def change_password(conn, %{password: password, password_confirmation: password_confirmation}) do
    conn
  end

  def update_username(conn, %{user_name: user_name}) do
    conn
  end

  def update(conn, attrs) do
    conn
  end
end
