defmodule ChatApiWeb.AuthJSON do
  def login(%{auth_token: auth_token, refresh_token: refresh_token}) do
    %{auth_token: auth_token, refresh_token: refresh_token}
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
