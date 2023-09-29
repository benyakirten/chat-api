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

  def register(conn, %{"email" => email, "password" => password}) do
    with {:ok, user, profile, auth_token, refresh_token} <-  Account.create_user(email, password) do
      # Signing up and signing in will have the same response body
      render(conn, :login, [user: user, profile: profile, auth_token: auth_token, refresh_token: refresh_token])
    end
  end

  def signout(conn, %{"user_id" => user_id, "refresh_token" => refresh_token}) do
    case Account.sign_out(user_id, refresh_token) do
      {:ok, :signed_out} -> send_204(conn) # TODO: Transmit via socket that user has logged out
      {:ok, :remaining_signins} -> send_204(conn)
      error -> error
    end
  end

  defp send_204(conn) do
    conn
    |> put_status(:no_content)
    |> put_resp_header("content-type", "application/json")
    |> send_resp(204, "")
  end

  # def confirm_email(conn, %{token: token}) do
  #   conn
  # end

  # def reset_password(conn, %{token: token, password: password, password_confirmation: password_confirmation}) do
  #   conn
  # end

  # Changing password without resetting/changing username/changing profile will have to be done with an auth token
end
