defmodule ChatApiWeb.AuthJSON do
  alias ChatApi.Account.{User, UserProfile}

  def login(%{user: user, profile: profile, auth_token: auth_token, refresh_token: refresh_token}) do
    %{user: serialize_user(user, profile), auth_token: auth_token, refresh_token: refresh_token}
  end

  def refresh_auth(%{refresh_token: refresh_token, auth_token: auth_token}) do
    %{refresh_token: refresh_token, auth_token: auth_token}
  end

  def confirm_user(%{user: user}) do
    %{success: true, confirmed_at: user.confirmed_at}
  end

  def confirm_token(%{user: user}) do
    %{success: true, user: serialize_user(user)}
  end

  def serialize_user(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      display_name: user.display_name
    }
  end

  def serialize_user(%User{} = user, %UserProfile{} = profile) do
    %{
      id: user.id,
      email: user.email,
      confirmed_at: user.confirmed_at,
      display_name: user.display_name,
      hidden: profile.hidden,
      theme: profile.theme,
      magnification: profile.magnification
    }
  end
end
