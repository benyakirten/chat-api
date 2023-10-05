defmodule ChatApi.Chat.Conversation do
  alias ChatApi.Chat.{Message, Conversation}
  alias ChatApi.Account.User

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{
    alias: String.t(),
    private: :boolean
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversations" do
    field :alias, :string
    field :private, :boolean, default: false

    many_to_many(:users, User, join_through: "users_conversations", on_replace: :delete)
    has_many(:messages, Message)

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs \\ %{}) do
    conversation
    |> cast(attrs, [:private, :alias])
  end

  def user_conversations_query(user_id) do
    from(c in Conversation, join: u in assoc(c, :users), where: u.id == ^user_id, preload: [messages: ^from(m in Message, order_by: [desc: m.inserted_at])])
  end

  def unique_users_for_conversations_query(conversations, current_user_id) do
    conversation_ids = for conversation <- conversations, do: conversation.id
    from(c in Conversation, join: u in assoc(c, :users), where: c.id in ^conversation_ids and u.id != ^current_user_id, distinct: u, select: u)
  end

  defp convert_uuids_to_binary(uuids) do
    uuids
    |> Stream.map(&Ecto.UUID.dump/1)
    |> Stream.filter(fn result -> result != :error end)
    |> Stream.map(fn {:ok, uuid} -> uuid end)
    |> Enum.to_list()
  end

  def find_private_conversation_by_users_query(user_id1, user_id2) do
    # The users_conversations table IDs is represented as the raw binaries,
    # not strings. So we need to convert the strings to
    # binaries because it is much easier than converting the binaries
    # to strings inside of the clause
    user_ids = convert_uuids_to_binary([user_id1, user_id2])

    if length(user_ids) == 2 do
      from(
          c in Conversation,
          where: c.private == true,
          join: uc in subquery(
            from uc in "users_conversations",
            where: uc.user_id in ^user_ids,
            group_by: uc.conversation_id,
            select: uc.conversation_id,
            having: count(uc.user_id) == ^length(user_ids)
          ),
          on: c.id == uc.conversation_id,
          group_by: c.id
        )
    else
      {:error, :invalid_user_ids}
    end
  end

  def member_of_conversation_query(conversation_id, user_id) do
    from(c in Conversation, join: u in assoc(c, :users), where: c.id == ^conversation_id and u.id == ^user_id)
  end

  def get_user_group_conversation_query(conversation_id, user_id) do
    from(c in Conversation, join: u in assoc(c, :users), where: c.private == ^false and c.id == ^conversation_id and u.id == ^user_id, preload: :users)
  end

  def get_conversation(conversation_id) do
    from(c in Conversation, where: c.id == ^conversation_id)
  end

  def get_users_conversations_query(conversation_id, user_id) do
    [conversation_binary_id, user_binary_id] = convert_uuids_to_binary(([conversation_id, user_id]))
    from(uc in "users_conversations", where: uc.conversation_id == ^conversation_binary_id and uc.user_id == ^user_binary_id)
  end
end
