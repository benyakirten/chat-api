defmodule ChatApiWeb.ProfileController do
  use ChatApiWeb, :controller

  alias ChatApiWeb.AuthController
  alias ChatApi.Account

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

  def update_profile(%Plug.Conn{assigns: %{user_id: user_id}} = conn, opts) do
    with {:ok, profile} <- Account.update_profile_by_user_id(user_id, opts) do
      render(conn, :update_profile, profile: profile)
    end
  end

  def signout_all(%Plug.Conn{assigns: %{user_id: user_id}} = conn, _opts) do
    Account.sign_out_all(user_id)
    AuthController.send_204(conn)
  end

  def request_new_confirmation_token(%Plug.Conn{assigns: %{user_id: user_id}} = conn, _opts) do
    with user when not is_nil(user) <- Account.get_user(user_id),
         {:ok} <- Account.deliver_user_confirmation_instructions(user) do
      AuthController.send_204(conn)
    end
  end

  def request_email_change_token(%Plug.Conn{assigns: %{user_id: user_id}} = conn, _opts) do
    with user when not is_nil(user) <- Account.get_user(user_id),
         {:ok} <- Account.deliver_user_email_change_instructions(user) do
      AuthController.send_204(conn)
    end
  end

  def update_display_name(%Plug.Conn{assigns: %{user_id: user_id}} = conn, %{"display_name" => display_name}) do
    # TODO: Clean this up
    with user when not is_nil(user) <- Account.get_user(user_id) do
      if user.display_name == display_name do
        {:error, :display_name_unchanged}
      else
        case  Account.update_display_name(user, display_name) do
          {:ok, updated_user} -> render(conn, :update_display_name, [user: updated_user])
          error -> error
        end
      end
    end
  end
end
