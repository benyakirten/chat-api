defmodule ChatApiWeb.AuthJSON do
  alias ChatApi.Account.{User, UserProfile}

  def login(%{user: user, profile: profile, conversations: conversations, users: users, auth_token: auth_token, refresh_token: refresh_token}) do
    %{user: serialize_user(user, profile), conversations: serialize_conversations(conversations), users: serialize_users(users), auth_token: auth_token, refresh_token: refresh_token}
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

  def serialize_users(users) do
    for user <- users, do: serialize_user(user)
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
      magnification: profile.magnification,
    }
  end

  defp serialize_conversations(conversations) do
    for conversation <- conversations do
      serialize_conversation(conversation)
    end
  end

  defp serialize_conversation(conversation) do
    %{
      id: conversation.id,
      messages: serialize_messages(conversation.messages),
      private: conversation.private,
      alias: conversation.alias
    }
  end

  defp serialize_messages(messages) do
    for message <- messages do
      serialize_message(message)
    end
  end

  defp serialize_message(message) do
    %{
      sender: message.user_id,
      content: message.content,
      inserted_at: message.inserted_at,
      updated_at: message.updated_at
    }
  end
end
