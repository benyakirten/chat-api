defmodule ChatApiWeb.AuthJSON do
  alias ChatApi.Serializer

  def login(%{
        user: user,
        profile: profile,
        conversations: conversations,
        users: users,
        auth_token: auth_token,
        refresh_token: refresh_token
      }) do
    %{
      user: Serializer.serialize(user, profile),
      conversations: Serializer.serialize(conversations),
      users: Serializer.serialize(users),
      auth_token: auth_token,
      refresh_token: refresh_token
    }
  end

  def confirm_user(%{user: user}) do
    %{success: true, confirmed_at: user.confirmed_at}
  end

  def confirm_token(%{user: user}) do
    %{success: true, user: Serializer.serialize(user)}
  end
end
