defmodule ChatApi.Account do
  @moduledoc """
  The Account context.
  TODO: Make sure everything fails spectacularly - error handler will take care of it
  """

  import Ecto.Query, warn: false
  alias Ecto.{Multi, Changeset}
  alias ChatApi.Repo
  alias ChatApi.Account.{User, UserToken}
  alias ChatApi.Token

  @doc """
  Returns the list of users.

  TODO: Add pagination

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
      {:error, %Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a user's password. The password field should be the attempt at current user's password
  to be hashed and checked against the hash stored in the database. The attrs should be a map with
  two fields in it: %{password: <new_pass>, confirm_password: <new_pass>}. These fields should match.
  In addition, the new password should not match the old password.

  ## Options
  :password_reset - If the option is passed then all tokens for the user also will be deleted

  ## Examples - TODO
  """
  def update_user_password(user, password, attrs, opts \\ []) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)
      |> User.validate_new_password(attrs[:password])

    password_reset = Keyword.get(opts, :password_reset, false)

    if password_reset, do: update_user_and_delete_tokens(changeset), else: Repo.update(changeset)
  end

  def update_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> update_user_and_delete_tokens()
  end

  defp update_user_and_delete_tokens(changeset) do
    Multi.new()
    |> Multi.update(:user_update, changeset)
    |> Multi.delete_all(:delete_tokens, &UserToken.user_tokens_query(&1))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _changes_so_far} -> {:error, changeset}
    end
  end

  @doc """
  TODO
  """
  def update_user_name(user, attrs) do
    user
    |> User.user_name_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Attempt to login by an email and password. If successful, create the auth and refresh token
  and store the refresh token in the database.
  """
  def attempt_login(email, password) when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)

    if User.valid_password?(user, password) do
      {auth_token, refresh_token, new_token_changeset} = create_new_tokens(user)
      Repo.insert(new_token_changeset)

      {:ok, auth_token, refresh_token}
    else
      {:error, :invalid_credentials}
    end
  end

  @doc """
  Although we cannot invalidate a specific token,
  we can invalidate all refresh tokens for the user.
  """
  def sign_out_all(%User{} = user) do
    user
    |> UserToken.user_tokens_query([:refresh_token])
    |> Repo.delete_all()
  end

  # TODO: Do we need a signout function? Is this actually useful?
  @doc """
  Delete a refresh token from the table.
  """
  def revoke_refresh_token(%User{} = user, token) do
    %UserToken{}
    |> UserToken.changeset(token: token, context: "refresh_token")
    |> Changeset.put_assoc(user, :users)
    |> Repo.delete()
  end

  def refresh_token(token) do
    case UserToken.verify_hashed_token(token, :refresh_token) do
      {:ok, user, token} ->
        {auth_token, refresh_token, new_token_changeset} = create_new_tokens(user)
        used_token_changeset = token |> UserToken.changeset()

        Ecto.Multi.new()
        |> Multi.delete(:used_token, used_token_changeset)
        |> Multi.insert(:new_token, new_token_changeset)
        |> Repo.transaction()

        {:ok, auth_token, refresh_token}

      {:error} ->
        {:error, :invalid_token}
    end
  end

  defp create_new_tokens(%User{} = user) do
    auth_token = Token.generate_auth_token(user)
    {refresh_token, hashed_token} = UserToken.build_hashed_token()

    hashed_token_changeset =
      %UserToken{}
      |> UserToken.changeset(context: :refresh_token, token: hashed_token)
      |> Changeset.put_assoc(:user, user)

    {auth_token, refresh_token, hashed_token_changeset}
  end
end
