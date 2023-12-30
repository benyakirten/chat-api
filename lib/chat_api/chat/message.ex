defmodule ChatApi.Chat.Message do
  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias ChatApi.Chat.{MessageGroup, Message}
  alias ChatApi.Account.User

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
  def changeset(message, attrs \\ %{}) do
    message
    |> cast(attrs, [:content])
    |> validate_required([:content])
  end

  @spec message_by_sender_query(binary(), binary()) :: Ecto.Query.t()
  def message_by_sender_query(message_id, user_id) do
    from(m in Message, where: m.id == ^message_id and m.user_id == ^user_id)
  end

  @spec message_by_id_query(binary()) :: Ecto.Query.t()
  def message_by_id_query(message_id) do
    from(m in Message, where: m.id == ^message_id)
  end

  @spec messages_by_group_id_query(binary()) :: Ecto.Query.t()
  def messages_by_group_id_query(message_group_id) do
    from(m in Message, where: m.message_group_id == ^message_group_id)
  end
end
