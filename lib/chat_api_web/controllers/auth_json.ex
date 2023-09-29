defmodule ChatApiWeb.AuthJSON do
  alias ChatApi.Account.{User, UserProfile}
  def login(%{user: user, profile: profile, auth_token: auth_token, refresh_token: refresh_token}) do
    %{user: serialize_user(user, profile), auth_token: auth_token, refresh_token: refresh_token}
  end

  def signout(_opts) do
    ""
  end

  # def confirm_email(conn, %{token: token}) do
  #   conn
  # end

  # def reset_password(conn, %{token: token, password: password, password_confirmation: password_confirmation}) do
  #   conn
  # end

  # Changing password without resetting/changing username/changing profile will have to be done with an auth token

  defp serialize_user(%User{} = user, %UserProfile{} = profile) do
    %{
      id: user.id,
      email: user.email,
      user_name: user.user_name,
      hidden: profile.hidden,
      theme: profile.theme,
      magnification: profile.magnification
    }
  end
end
