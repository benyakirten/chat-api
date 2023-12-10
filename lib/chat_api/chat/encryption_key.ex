defmodule ChatApi.Chat.EncryptionKey do
  alias ChatApi.Chat.EncryptionKey
  alias ChatApi.Chat.Conversation
  alias ChatApi.Account.User
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  @typedoc "The JWK encrypted public or private key data."
  @type t :: %__MODULE__{
          :alg => binary(),
          :d => binary(),
          :dp => binary(),
          :dq => binary(),
          :e => binary(),
          :ext => boolean(),
          :key_ops => [binary()],
          :kty => binary(),
          :n => binary(),
          :p => binary(),
          :q => binary(),
          :qi => binary(),
          :type => binary()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversations" do
    field(:alg, :binary)
    field(:d, :binary)
    field(:dp, :binary)
    field(:dq, :binary)
    field(:e, :binary)
    field(:ext, :boolean)
    field(:key_ops, :binary)
    field(:kty, :binary)
    field(:n, :binary)
    field(:p, :binary)
    field(:q, :binary)
    field(:qi, :binary)
    field(:type, :binary)

    has_one(:user, User)
    has_one(:conversation, Conversation)

    timestamps()
  end

  @doc false
  def changeset(encryption_key, user, conversation, attrs \\ %{}) do
    encryption_key
    |> cast(attrs, [:alg, :d, :dp, :dq, :e, :ex, :key_ops, :kt, :n, :p, :q, :qi, :type])
    |> validate_required([:alg, :d, :dp, :dq, :e, :ex, :key_ops, :kt, :n, :p, :q, :qi, :type])
    |> put_assoc(:user, user)
    |> put_assoc(:conversation, conversation)
  end

  def get_key_by_user_conversation_type_query(user_id, conversation_id, type) do
    from(
      k in EncryptionKey,
      where: k.user_id == ^user_id and k.conversation_id == ^conversation_id and k.type == ^type
    )
  end
end
