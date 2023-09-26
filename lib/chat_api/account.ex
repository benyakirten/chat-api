defmodule ChatApi.Account do
  @moduledoc """
  The Account context.
  """

  import Ecto.Query, warn: false
  alias ChatApi.Repo

  alias ChatApi.Account.{User, UserToken}

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Get a single user by their email address.

  Raises `Ecto.NoResultsError` if the User cannot be found by that email.

  ## Examples

      iex> get_user_by_email!("test@test.com")
      %User{}

      iex> get_user_by_email!("test")
      ** (Ecto.NoResultsError)
  """
  def get_user_by_email!(email), do: Repo.get_by!(User, email: email)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # TODO: Update/delete user

  @doc """
  Update a user's password. The password field should be the attempt at current user's password
  to be hashed and checked against the hash stored in the database. The attrs should be a map with
  two fields in it: %{password: <new_pass>, confirm_password: <new_pass>}. These fields should match.
  In addition, the new password should not match the old password.
  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)
      |> User.validate_new_password(attrs[:password])

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user_password, changeset)
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{user: user} ->
      UserToken.revoke_user_tokens_query(user)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _changes_so_far} -> {:error, changeset}
    end
  end

  @doc """
  Attempt to login by an email and password. If successful, create the auth and refresh token
  and store the refresh token in the database.
  """
  def attempt_login(email, password) when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)

    if User.valid_password?(user, password) do
      auth_token = ChatApi.Token.generate_token(user.id, :auth)
      refresh_token = ChatApi.Token.generate_token(user.id, :refresh_token)

      %UserToken{}
      |> UserToken.changeset(context: :refresh_token, token: refresh_token, user_id: user.id)
      |> Repo.insert()

      {:ok, [auth_token: auth_token, refresh_token: refresh_token]}
    else
      {:error, :invalid_credentials}
    end
  end
end
