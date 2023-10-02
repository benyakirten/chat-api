defmodule ChatApi.Chat.Message do
  alias ChatApi.Chat.{Conversation, Message}
  alias ChatApi.Account.User
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "messages" do
    field :content, :string

    belongs_to(:user, User)
    belongs_to(:conversation, Conversation)

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content])
    |> validate_required([:content])
  end

  def add_user_and_conversation(message, user_id, conversation_id) do
    message
    |> cast(%{user_id: user_id, conversation_id: conversation_id}, [:user_id, :conversation_id])
  end
end
