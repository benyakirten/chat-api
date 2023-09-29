defmodule ChatApiWeb.AuthController do
  use ChatApiWeb, :controller

  alias ChatApi.Account

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

  def confirm_user(conn, %{"token" => token}) do
    with {:ok, _} <- Account.confirm_user(token) do
      send_204(conn)
    end
  end

  def request_new_confirmation(conn, %{"email" => email}) do
    with user when not is_nil(user) <- Account.get_user_by_email(email),
      {:ok} <- Account.deliver_user_confirmation_instructions(user)
    do
      send_204(conn)
    end
  end

  def request_password_reset_token(conn, %{"email" => email}) do
    with user when not is_nil(user) <- Account.get_user_by_email(email),
      {:ok} <- Account.deliver_user_password_reset_instructions(user)
    do
      send_204(conn)
    end
  end

  def confirm_password_reset_token(conn, %{"token" => token}) do
    with {:ok, user} <- Account.confirm_token(token, :password_reset) do
      render(conn, :confirm_token, [user: user])
    end
  end

  def reset_password(
    conn,
    %{
      "token" => token,
      "password" => password,
      "new_password" => new_password,
      "new_password_confirmation" => new_password_confirmation,
    }) do
    with {:ok, user} <- Account.confirm_token(token, :password_reset) do
      case Account.update_user_password(
        user,
        password,
        %{password: new_password, password_confirmation: new_password_confirmation},
        [password_reset: true]
      ) do
        {:ok, _} -> send_204(conn)
        {:error, _, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
        error -> error
      end
    end
  end

  # This should require authentication
  def update_email(conn, %{"token" => token, "email" => email, "password" => password}) do
    with {:ok, user} <- Account.confirm_token(token, :email_change) do
      case Account.update_user_email(
        user,
        password,
        %{email: email}
      ) do
        {:ok, _} -> send_204(conn)
        {:error, _, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
        error -> error
      end
    end
  end

  # Requesting an email change token will require the user to be authenticated
  # Changing password without reset/changing username/changing email without a token/changing profile will have to be done with an auth token
end
