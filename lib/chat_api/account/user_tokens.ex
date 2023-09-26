defmodule ChatApi.Account.UserToken do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias ChatApi.Repo
  alias ChatApi.Token

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)

    belongs_to(:user, ChatApi.Account.User)

    timestamps()
  end

  @doc """
  Given a user id, see if the user tokens table contains a token for the specified context.

  The function allows tokens other than auth tokens can be revoked and checked for authenticity.
  We want to be able to send tokens to confirm an email address, change it, reset a password
  or refresh authorization, but we also want to be able to arbitrarily revoke them. To be
  able to do so, we store them in a database table.

  The authorization token itself cannot be revoked, but it only has a lifespan of 30 minutes.
  """
  @spec check_token_by_context(String.t(), Token.token_type()) ::
          {:ok, String.t()} | {:error, :revoked}
  def check_token_by_context(user_id, context) do
    [tokens_found] =
      Repo.all(
        from(t in UserToken,
          where: :user_id == ^user_id and :context == ^to_string(context),
          select: count(t.id)
        )
      )

    if tokens_found > 0, do: {:ok, user_id}, else: {:error, :revoked}
  end
end
