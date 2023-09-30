defmodule ChatApiWeb.ProfileController do
  use ChatApiWeb, :controller

  alias ChatApiWeb.AuthController
  alias ChatApi.Account
  # alias ChatApi.Account.User

  action_fallback ChatApiWeb.FallbackController

  def update_password(
        %Plug.Conn{assigns: %{user_id: user_id}} = conn,
        %{
          "password" => password,
          "new_password" => new_password,
          "new_password_confirmation" => new_password_confirmation
        }
      ) do
    with user when not is_nil(user) <- Account.get_user(user_id) do
      case Account.update_user_password(
             user,
             password,
             %{password: new_password, password_confirmation: new_password_confirmation},
             password_reset: true
           ) do
        {:ok, _} -> AuthController.send_204(conn)
        {:error, _, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
        error -> error
      end
    end
  end

  def update_email(
        %Plug.Conn{assigns: %{user_id: user_id}} = conn,
        %{
          "token" => token,
          "email" => email,
          "password" => password
        }
      ) do
    with {:ok, user} <- Account.confirm_token(token, :email_change) do
      if user.id == user_id do
        case Account.update_user_email(
               user,
               password,
               %{email: email}
             ) do
          {:ok, _} -> AuthController.send_204(conn)
          {:error, _, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
          error -> error
        end
      else
        {:error, :invalid_token}
      end
    end
  end
end
