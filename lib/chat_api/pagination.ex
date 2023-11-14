defmodule ChatApi.Pagination do
  import Ecto.Query
  alias ChatApi.Serializer

  @spec add_pagination_token_to_query(Ecto.Query.t(), map()) :: Ecto.Query.t()
  def add_pagination_token_to_query(query, opts) do
    with next_token when not is_nil(next_token) <- Map.get(opts, "next"),
         {:ok, time, id} <- Serializer.decode_token(next_token) do
      query
      |> where([u], {u.inserted_at, u.id} < {^time, ^id})
    else
      _ -> query
    end
  end
end
