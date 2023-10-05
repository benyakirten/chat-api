defmodule ChatApiWeb.AuthJSON do
  alias ChatApi.Chat.Conversation
  alias ChatApi.Account.User

  def login(%{
        user: user,
        profile: profile,
        conversations: conversations,
        users: users,
        auth_token: auth_token,
        refresh_token: refresh_token
      }) do
    %{
      user: User.serialize(user, profile),
      conversations: Conversation.serialize(conversations),
      users: User.serialize(users),
      auth_token: auth_token,
      refresh_token: refresh_token
    }
  end

  def refresh_auth(%{refresh_token: refresh_token, auth_token: auth_token}) do
    %{refresh_token: refresh_token, auth_token: auth_token}
  end

  def confirm_user(%{user: user}) do
    %{success: true, confirmed_at: user.confirmed_at}
  end

  def confirm_token(%{user: user}) do
    %{success: true, user: User.serialize(user)}
  end
end
