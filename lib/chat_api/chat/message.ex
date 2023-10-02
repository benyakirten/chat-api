defmodule ChatApi.Chat.Message do
  alias ChatApi.Chat.Conversation
  alias ChatApi.Account.User
  use Ecto.Schema
  import Ecto.Changeset

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
end
