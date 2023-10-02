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
end
