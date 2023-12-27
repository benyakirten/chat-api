defmodule ChatApi.Chat.Message do
  alias ChatApi.Pagination
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

    belongs_to(:user, User)

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

  @spec paginate_messages_query(binary(), map() | nil) :: {Ecto.Query.t(), integer()}
  def paginate_messages_query(conversation_id, opts \\ %{}) do
    page_size = Pagination.get_page_size(opts)

    query =
      from(m in Message)
      |> where([m], m.conversation_id == ^conversation_id)
      |> Pagination.add_seek_pagination(page_size)
      |> Pagination.paginate_from(opts)

    {query, page_size}
  end
end
