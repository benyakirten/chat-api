defmodule ChatApi.Chat.Conversation do
  alias ChatApi.Account.User
  alias ChatApi.Chat.Message
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversations" do
    field :alias, :string
    field :private, :boolean, default: false

    many_to_many(:users, User, join_through: "users_conversations")
    has_many(:messages, Message)

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:private, :alias])
    |> validate_required([:private])
  end
end
