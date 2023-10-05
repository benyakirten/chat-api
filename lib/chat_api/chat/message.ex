defmodule ChatApi.Chat.Message do
  alias ChatApi.Chat.{Conversation, Message}
  alias ChatApi.Account.User
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{
    content: String.t()
  }

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

  def message_by_sender_query(message_id, user_id) do
    from(m in Message, where: m.id == ^message_id and m.user_id == ^user_id)
  end

  def serialize_messages(messages) do
    for message <- messages do
      serialize_message(message)
    end
  end

  def serialize_message(message) do
    %{
      sender: message.user_id,
      content: message.content,
      inserted_at: message.inserted_at,
      updated_at: message.updated_at
    }
  end
end
