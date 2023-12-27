defmodule ChatApi.Chat.MessageGroup do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias ChatApi.Chat.{Message, MessageGroup, Conversation}
  alias ChatApi.Account.User
  alias ChatApi.Pagination

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "message_groups" do
    belongs_to(:user, User, foreign_key: :sender_user_id)
    belongs_to(:conversation, Conversation)
    has_many(:messages, Message)
  end

  @doc false
  def new(conversation, user) do
    %MessageGroup{}
    |> cast(%{}, [])
    |> put_assoc(:conversation, conversation)
    |> put_assoc(:user, user)
  end

  @spec paginate_messages_query(any(), any(), map()) ::
          {Ecto.Query.t(), pos_integer()}
  def paginate_messages_query(conversation_id, user_id, opts \\ %{}) do
    page_size = Pagination.get_page_size(opts)

    # We're usign this as a CTE instead of joins because we want to reuse
    # the pagination logic in Pagination.add_seek_pagination/2 and Pagination.paginate_from/2
    message_group_cte =
      from(mg in MessageGroup,
        where: mg.conversation_id == ^conversation_id
      )

    query =
      Message
      |> with_cte("message_group", as: ^message_group_cte)
      |> join(:inner, [m], mg in "message_group", on: m.message_group_id == mg.id)
      |> where([m], m.recipient_user_id == ^user_id)
      |> Pagination.add_seek_pagination(page_size)
      |> Pagination.paginate_from(opts)

    {query, page_size}
  end

  @spec message_group_by_id_and_user_query(binary(), binary()) :: Ecto.Query.t()
  def message_group_by_id_and_user_query(message_group_id, user_id) do
    from(mg in MessageGroup,
      where: mg.id == ^message_group_id and mg.sender_user_id == ^user_id
    )
  end

  def messages_in_message_group_query(message_group_id) do
    from(mg in MessageGroup,
      where: mg.id == ^message_group_id,
      join: m in assoc(mg, :messages),
      select: m
    )
  end
end
