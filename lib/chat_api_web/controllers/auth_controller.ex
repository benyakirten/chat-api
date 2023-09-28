defmodule ChatApiWeb.AuthController do
  use ChatApiWeb, :controller

  alias ChatApi.Account
  # alias ChatApi.Account.User

  action_fallback ChatApiWeb.FallbackController

  def login(conn, %{"email" => email, "password" => password}) do
    with {:ok, user, profile, auth_token, refresh_token} <-  Account.login(email, password) do
      render(conn, :login, [user: user, profile: profile, auth_token: auth_token, refresh_token: refresh_token])
    end
  end

  # def register(conn, attrs) do
  #   conn
  # end

  # def signout(conn, %{refresh_token: refresh_token}) do
  #   conn
  # end

  # def confirm_email(conn, %{token: token}) do
  #   conn
  # end

  # def reset_password(conn, %{token: token, password: password, password_confirmation: password_confirmation}) do
  #   conn
  # end

  # Changing password without resetting/changing username/changing profile will have to be done with an auth token
end
