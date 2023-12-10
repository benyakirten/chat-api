defmodule ChatApi.Chat.EncryptionKey do
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
          :qi => binary()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversations" do
    field :alg, :binary
    field :d, :binary
    field :dp, :binary
    field :dq, :binary
    field :e, :binary
    field :ext, :boolean
    field :key_ops, :binary
    field :kty, :binary
    field :n, :binary
    field :p, :binary
    field :q, :binary
    field :qi, :binary
    field :type, :binary

    has_one(:conversations, Conversation)
    has_one(:users, User)

    timestamps()
  end
end
