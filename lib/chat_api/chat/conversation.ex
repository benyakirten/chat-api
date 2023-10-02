defmodule ChatApi.Chat.Conversation do
  alias ChatApi.Chat.{Message, Conversation}
  alias ChatApi.Account.User
  alias ChatApi.Repo
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

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
    from(c in Conversation, join: u in assoc(c, :users), where: u.id == ^user_id, preload: :messages)
  end

  def new_conversation_query(user_ids, message_content, message_sender) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:create_conversation, Conversation.changeset(%Conversation{}))
    # Repo.preload gives errors in IEX - This is a temporary measure to preload the users
    # While debugging the query
    |> Ecto.Multi.run(:get_conversation, fn _repo, %{create_conversation: conversation} ->
      convo = Repo.one(from(c in Conversation, where: c.id == ^conversation.id, preload: :users))
      case convo do
        nil -> {:error, :missing_conversation}
        convo -> {:ok, convo}
      end
    end)
    |> Ecto.Multi.run(:add_message, fn _repo, %{get_conversation: conversation} ->
      %Message{}
      |> Message.changeset(%{content: message_content, conversation_id: conversation.id, user_id: message_sender})
      |> Repo.insert()
    end)
    |> Ecto.Multi.all(:get_users, from(u in User, where: u.id in ^user_ids, select: u))
    |> Ecto.Multi.run(:apply_users, fn _repo, %{get_users: users, get_conversation: conversation} ->
      conversation
      |> changeset()
      |> put_assoc(:users, users)
      |> Repo.update()
    end)
  end
end
