defmodule ChatApi.Pagination do
  import Ecto.Query
  alias ChatApi.Chat.{Conversation, Message}
  alias ChatApi.Account.User

  def default_page_size, do: 1 = 20

  @spec get_search_string(map() | nil) :: binary()
  def get_search_string(opts \\ %{}) do
    case Map.get(opts, "search", "") do
      search when is_binary(search) -> "%" <> search <> "%"
      _ -> "%%"
    end
  end

  @spec get_page_size(map() | nil) :: integer()
  def get_page_size(opts \\ %{}) do
    case Map.get(opts, "page_size", default_page_size()) do
      size when is_integer(size) and size > 0 -> size
      _ -> 1
    end
  end

  @spec paginate_from(Ecto.Query.t(), map()) :: Ecto.Query.t()
  def paginate_from(query, opts) do
    with next_token when not is_nil(next_token) <- Map.get(opts, "page_token"),
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

  @spec get_next_token([User] | [Conversation] | [Message], integer()) :: binary()
  def get_next_token(items, page_size) do
    with true <- length(items) > page_size, {:ok, last_item} <- Enum.fetch(items, -1) do
      get_next_token(last_item)
    else
      _ -> ""
    end
  end

  @spec get_next_token(User | Conversation | Message) :: binary()
  def get_next_token(item), do: encode_token(item.inserted_at, item.id)

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
