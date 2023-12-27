defmodule ChatApi.Chat.MessageGroup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "message_groups" do

    field :user_id, :id
    field :conversation_id, :id
    field :message_id, :id

    timestamps()
  end

  @doc false
  def changeset(message_group, attrs) do
    message_group
    |> cast(attrs, [])
    |> validate_required([])
  end
end
