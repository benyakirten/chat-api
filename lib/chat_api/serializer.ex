defmodule ChatApi.Serializer do
  alias ChatApi.Chat.{Conversation, Message}
  alias ChatApi.Account.{User, UserProfile}

  @doc """
  Serialize a list of items and provide a next page token
  """
  def serialize_all(items, has_next_token) do
    next_token = case has_next_token do
      true ->
        [item] = Enum.take(items, -1)
        get_next_token(item)
      false -> ""
    end

    %{
      items: serialize(items),
      next: next_token
    }
  end

  def serialize([head | tail]) do
    [serialize(head) | serialize(tail)]
  end

  def serialize(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      display_name: user.display_name
    }
  end

  def serialize(%UserProfile{} = profile) do
    magnification = coerce_float(profile.magnification)

    %{
      hidden: profile.hidden,
      theme: profile.theme,
      magnification: magnification,
      recents: profile.recents
    }
  end

  def serialize(%Message{} = message) do
    %{
      id: message.id,
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
    |> Map.merge(%{confirmed_at: user.confirmed_at})
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

  defp coerce_float(%Decimal{} = magnification) do
    {val, _} = magnification |> to_string() |> Float.parse()
    val
  end

  defp coerce_float(magnification), do: magnification

  @spec get_next_token(%{
          :__struct__ => ChatApi.Account.User | ChatApi.Chat.Conversation | ChatApi.Chat.Message,
          :id => binary(),
          :inserted_at => NaiveDateTime.t(),
        }) :: binary()
  def get_next_token(%User{} = user), do: encode_token(user.inserted_at, user.id)
  def get_next_token(%Conversation{} = conversation), do: encode_token(conversation.inserted_at, conversation.id)
  def get_next_token(%Message{} = message), do: encode_token(message.inserted_at, message.id)

  @spec encode_token(NaiveDateTime.t(), binary()) :: binary()
  def encode_token(time, id) do
    time_str = NaiveDateTime.to_string(time)
    json_encoded = Jason.encode!(%{"inserted_at" => time_str, "id" => id})
    Base.encode64(json_encoded)
  end

  @spec decode_token(binary()) :: {:error, :invalid_token} | {:ok, NaiveDateTime.t(), binary()}
  def decode_token(token) do
    with {:ok, json_encoded} <- Base.decode64(token),
      {:ok, %{"inserted_at" => inserted_at, "id" => id}} <- Jason.decode(json_encoded), {:ok, time} <- NaiveDateTime.from_iso8601(inserted_at) do
      {:ok, time, id}
    else
      _ -> {:error, :invalid_token}
    end
  end
end
