defmodule ChatApi.Serializer do
  alias ChatApi.Chat.{Conversation, Message}
  alias ChatApi.Account.{User, UserProfile}

  def serialize([head | tail]) do
    [serialize(head) | serialize(tail)]
  end

  def serialize(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      confirmed_at: user.confirmed_at,
      display_name: user.display_name
    }
  end

  def serialize(%UserProfile{} = profile) do
    %{
      hidden: profile.hidden,
      theme: profile.theme,
      magnification: profile.magnification,
      recents: profile.recents
    }
  end

  def serialize(%Message{} = message) do
    %{
      sender: message.user_id,
      content: message.content,
      inserted_at: attach_javascript_timezone(message.inserted_at),
      updated_at: attach_javascript_timezone(message.updated_at)
    }
  end

  def serialize(%Conversation{} = conversation) do
    %{
      id: conversation.id,
      private: conversation.private,
      alias: conversation.alias,
      inserted_at: attach_javascript_timezone(conversation.inserted_at),
      updated_at: attach_javascript_timezone(conversation.updated_at)
    }
  end

  def serialize([]) do
    []
  end

  def serialize(%User{} = user, %UserProfile{} = profile) do
    %{}
    |> Map.merge(serialize(user))
    |> Map.merge(serialize(profile))
  end

  # Ecto stores times without the time zone data, but they're all UTC.
  # If you add this string then they will be parsed as UTC time and
  # not local time when they are parsed initially.
  # E.G. the time will be given as ~N[2023-10-05 21:25:49], which,
  # when converted to a string by jason, will be 2023-10-05T21:25:49.
  # JavaScript's new Date() will return that that time as the local
  # time in whatever time zone the user is in. So the time
  # will be interpreted as 9 PM in the user's local time.
  # The purpose of this function is to make JavaScript
  # intrepret the datetime as in UTC time. It
  # will take ~N[2023-10-05 21:25:49], convert it to a string
  # then add the UTC time zone data to it, so it will be
  # represented as the string: 2023-10-05 21:25:49+00.00
  # which will be parsed by new Date() relative to the user's
  # current time zone.
  # And yes, this is easier than converting a naive date time
  # to a UTC datetime using Elixir since I would need to use
  # an outside library - this is just simple.
  def attach_javascript_timezone(nil) do
    nil
  end

  def attach_javascript_timezone(time) do
    to_string(time) <> "Z"
  end
end
