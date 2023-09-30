defmodule ChatApi.Account.UserToken do
  @moduledoc """
  A module for handling processing of tokens that are not user tokens.
  While auth tokens have a short lifespan (30 minutes), these tokens will
  on the order of days. They are not encrypted, but when they are generated
  a base-64 encoded version and a hashed version is generated. The former
  version is sent to the client once, while the latter is stored in the database.
  When the user attempts to use a token, they are decoded from base-64 then hashed
  to check for a match against the database. The objective is to prevent users with
  read-only access to the database from gaining access to one of the tokens.
  """
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias ChatApi.Repo
  alias ChatApi.Account.{User, UserToken}

  @type t :: %__MODULE__{
          token: :binary,
          context: String.t()
        }
  @type token_type :: :refresh_token | :password_reset | :email_confirmation | :email_change

  @hash_algorithm :sha256
  @rand_size 32
  @refresh_token_lifespan_in_days 14
  @password_reset_token_lifespan_in_days 1
  @email_confirm_token_lifespan_in_days 7
  @email_change_token_lifespan_in_days 7

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)

    belongs_to(:user, User)

    timestamps(updated_at: false)
  end

  @doc false
  @spec changeset(UserProfile.t(), User.t(), map()) :: UserProfile.t()
  def changeset(user_token, user, attrs \\ %{}) do
    user_token
    |> cast(attrs, [:token, :context])
    |> validate_required([:token, :context])
    |> put_assoc(:user, user)
  end

  @spec token_lifespan_for_context(token_type) :: number()
  defp token_lifespan_for_context(:refresh_token), do: @refresh_token_lifespan_in_days
  defp token_lifespan_for_context(:password_reset), do: @password_reset_token_lifespan_in_days
  defp token_lifespan_for_context(:email_confirmation), do: @email_confirm_token_lifespan_in_days
  defp token_lifespan_for_context(:email_change), do: @email_change_token_lifespan_in_days

  @doc """
  Given a user id, see if the user tokens table contains a token for the specified context.

  The function allows tokens other than auth tokens to be revoked and checked for authenticity.
  We want to be able to send tokens to confirm an email address, change it, reset a password
  or refresh authorization, but we also want to be able to arbitrarily revoke them. To be
  able to do so, we store them in a database table.

  The authorization token itself cannot be revoked, but it only has a lifespan of 30 minutes.
  """
  @spec get_active_user_tokens_for_context(String.t(), token_type()) :: Ecto.Query.t()
  def get_active_user_tokens_for_context(user_id, context) do
    lifespan = token_lifespan_for_context(context)

    from(t in UserToken,
      where:
        t.user_id == ^user_id and t.context == ^to_string(context) and
          t.inserted_at > ago(^lifespan, "day")
    )
  end

  def user_token_query(user_id, hashed_token) do
    from(t in UserToken, where: t.user_id == ^user_id and t.token == ^hashed_token)
  end

  @spec hash_token(String.t()) :: {:ok, binary()} | {:error}
  def hash_token(token) do
    with {:ok, decoded_token} <- Base.url_decode64(token, padding: false),
         hashed_token <- :crypto.hash(@hash_algorithm, decoded_token) do
      {:ok, hashed_token}
    else
      _ -> {:error}
    end
  end

  @doc """
  Get all tokens associated with the user. If a user resets their
  password, changes their email or forces all devices to sign out
  then we want to be able to delete all the user's tokens.
  """
  def user_tokens_by_context_query(
        user_id,
        contexts \\ [:refresh_token, :password_reset, :email_confirmation, :email_change]
      ) do
    string_contexts = Enum.map(contexts, &to_string(&1))
    from(t in UserToken, where: t.user_id == ^user_id and t.context in ^string_contexts)
  end

  @spec remove_stale_token_query(Ecto.Multi.t()) :: Ecto.Multi.t()
  def remove_stale_token_query(multi_query) do
    Enum.reduce(
      [:refresh_token, :password_reset, :email_confirmation, :email_change],
      multi_query,
      fn acc, next ->
        lifespan = token_lifespan_for_context(next)

        Ecto.Multi.delete_all(
          acc,
          next,
          from(t in UserToken,
            where: t.context == ^to_string(next) and t.inserted_at > ago(^lifespan, "day")
          )
        )
      end
    )
  end

  @doc """
  Generates a token and returns a base-64 encoded copy and a hashed copy.

  The non-hashed token is sent to the user while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access.
  """
  @spec build_hashed_token() :: {String.t(), binary()}
  def build_hashed_token() do
    with token <- :crypto.strong_rand_bytes(@rand_size),
         hashed_token <- :crypto.hash(@hash_algorithm, token),
         url_encoded <- Base.url_encode64(token, padding: false) do
      {url_encoded, hashed_token}
    end
  end

  @doc """
  Given a base-64 encoded token, decode it and check 1. if the hashed version exists
  in the database and 2. if the token is still valid.

  This allows all tokens (or a specific token) for a user to be revoked
  """
  @spec verify_hashed_token(String.t(), token_type()) :: {:ok, User.t(), UserToken.t()} | {:error}
  def verify_hashed_token(token, context) do
    with {:ok, hashed_token} <- hash_token(token),
         {user, retrieved_token} <-
           Repo.one(verify_hashed_token_query(hashed_token, context)) do
      {:ok, user, retrieved_token}
    else
      _ -> {:error}
    end
  end

  defp verify_hashed_token_query(hashed_token, context) do
    lifespan = token_lifespan_for_context(context)

    from(t in UserToken,
      where:
        t.token == ^hashed_token and t.context == ^to_string(context) and
          t.inserted_at > ago(^lifespan, "day"),
      join: u in assoc(t, :user),
      select: {u, t}
    )
  end

  @spec new_changeset_from_token_context(binary(), token_type(), User.t()) :: Ecto.Changeset.t()
  def new_changeset_from_token_context(token, context, user) do
    changeset(%UserToken{}, user, %{token: token, context: to_string(context)})
  end
end
