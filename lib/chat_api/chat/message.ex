defmodule ChatApi.Chat.Message do
  alias ChatApi.Chat.MessageGroup
  alias ChatApi.Chat.Message
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
    field(:content, :string)

    belongs_to(:user, User, foreign_key: :recipient_user_id)
    belongs_to(:message_group, MessageGroup)

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

  def message_by_id_query(message_id) do
    from(m in Message, where: m.id == ^message_id)
  end
end
