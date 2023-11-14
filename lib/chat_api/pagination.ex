defmodule ChatApi.Pagination do
  import Ecto.Query
  alias ChatApi.Chat.{Conversation, Message}
  alias ChatApi.Account.User

  @spec get_search_string(map() | nil) :: binary()
  def get_search_string(opts \\ %{}) do
    case Map.get(opts, "search", "") do
      search when is_binary(search) -> "%" <> search <> "%"
      _ -> "%%"
    end
  end

  @spec get_page_size(map() | nil) :: integer()
  def get_page_size(opts \\ %{}) do
    case Map.get(opts, "page_size", 10) do
      size when is_integer(size) and size > 0 -> size
      _ -> 1
    end
  end

  @spec paginate_from(Ecto.Query.t(), map()) :: Ecto.Query.t()
  def paginate_from(query, opts) do
    with next_token when not is_nil(next_token) <- Map.get(opts, "next"),
         {:ok, time, id} <- decode_token(next_token) do
      query |> where([u], {u.inserted_at, u.id} < {^time, ^id})
    else
      _ -> query
    end
  end

  @spec add_seek_pagination(Ecto.Query.t(), integer()) :: Ecto.Query.t()
  def add_seek_pagination(query, page_size) do
    query
    |> order_by([u], desc: u.inserted_at, desc: u.id)
    |> limit(^(page_size + 1))
  end

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

    Jason.encode!(%{"inserted_at" => time_str, "id" => id})
    |> Base.encode64()
  end

  @spec decode_token(binary()) :: {:error, :invalid_token} | {:ok, NaiveDateTime.t(), binary()}
  def decode_token(token) do
    with {:ok, json_encoded} <- Base.decode64(token),
      {:ok, %{"inserted_at" => inserted_at, "id" => id}} <- Jason.decode(json_encoded),
      {:ok, time} <- NaiveDateTime.from_iso8601(inserted_at) do
        {:ok, time, id}
    else
    _ -> {:error, :invalid_token}
    end
  end
end
