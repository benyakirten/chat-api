defmodule ChatApi.Account.UserToken do
  use Ecto.Schema
  import Ecto.Query

  schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)

    belongs_to(:user, ChatApi.Account.User)

    timestamps()
  end
end
