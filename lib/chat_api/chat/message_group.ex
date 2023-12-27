defmodule ChatApi.Chat.MessageGroup do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias ChatApi.Chat.{Message, MessageGroup, Conversation}
  alias ChatApi.Account.User
  alias ChatApi.Pagination

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "message_groups" do
    belongs_to(:user, User)
    belongs_to(:conversation, Conversation)
    belongs_to(:message, Message)
  end

  @doc false
  def new(conversation, user, message) do
    %MessageGroup{}
    |> cast(%{}, [])
    |> put_assoc(:conversation, conversation)
    |> put_assoc(:user, user)
    |> put_assoc(:message, message)
  end

  @spec paginate_messages_for_user_in_conversation_query(any(), any(), map()) ::
          {Ecto.Query.t(), pos_integer()}
  def paginate_messages_for_user_in_conversation_query(conversation_id, user_id, opts \\ %{}) do
    page_size = Pagination.get_page_size(opts)

    # We're usign this as a CTE instead of joins because we want to reuse
    # the pagination logic in Pagination.add_seek_pagination/2 and Pagination.paginate_from/2
    message_group_cte =
      from(mg in MessageGroup,
        where: mg.conversation_id == ^conversation_id and mg.user_id == ^user_id
      )

    query =
      Message
      |> with_cte("message_group", as: ^message_group_cte)
      |> join(:inner, [m], mg in "message_group", on: m.id == mg.message_id)
      |> Pagination.add_seek_pagination(page_size)
      |> Pagination.paginate_from(opts)

    {query, page_size}
  end
end
