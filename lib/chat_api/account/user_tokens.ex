defmodule ChatApi.Account.UserToken do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias ChatApi.{Repo, Token}
  alias ChatApi.Account.{User, UserToken}

  @hash_algorithm :sha256
  @rand_size 32

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)

    belongs_to(:user, User)

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(user_token, attrs) do
    user_token
    |> cast(attrs, [:token, :context])
    |> validate_required([:token, :context])
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
    result =
      Repo.one(
        from(t in UserToken,
          where: :user_id == ^user_id and :context == ^to_string(context),
          select: count(t.id)
        )
      )

    if result, do: {:ok, user_id}, else: {:error, :revoked}
  end

  @doc """
  Deletes all tokens associated with the user. If a user resets their
  password or changes their email, then they will not be able to use
  any of their pending tokens.
  """
  def revoke_user_tokens_query(%User{id: user_id} = user) do
    from(t in UserToken, where: :user_id == ^user_id)
  end

  @doc """
  Builds a token and its hash to be delivered to the user's email.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the user changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  def build_hashed_token(user, context) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: hashed_token,
       context: context,
       user_id: user.id
     }}
  end

  def verify_hashed_token(user, context) do
    with decoded_token <- Base.url_decode64(token, padding: false),
         hashed_token <- :crypto.hash(@hash_algorithm, decoded_token),
         lifespan <- Token.token_lifespan_for_context(context),
         result when not is_nil(result) <-
           verify_hashed_token_query(hashed_token, context, lifespan)

    {:ok}
  else
    _ -> {:error}
  end

  defp verify_hashed_token_query(hashed_token, context, lifespan) do
    Repo.one(
      from(
        t in UserToken,
        where(
          t.token == ^hashed_token and t.context == ^context and
            token.inserted_at > ago(lifespan, "second")
        )
      )
    )
  end
end
