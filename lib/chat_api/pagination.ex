defmodule ChatApi.Pagination do
  import Ecto.Query
  alias ChatApi.Serializer

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
         {:ok, time, id} <- Serializer.decode_token(next_token) do
      query
      |> where([u], {u.inserted_at, u.id} < {^time, ^id})
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
end
