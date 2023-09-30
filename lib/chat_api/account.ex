defmodule ChatApi.Account do
  @moduledoc """
  The Account context.
  TODO: Make sure everything fails spectacularly - error handler will take care of it
  """

  alias ChatApi.{Repo, Token}
  alias ChatApi.Account.{User, UserToken, UserProfile, UserNotifier}

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
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Get a single user by their email address.

  Raises `Ecto.NoResultsError` if the User cannot be found by that email.

  ## Examples

      iex> get_user_by_email!("test@test.com")
      %User{}

      iex> get_user_by_email!("test")
      ** (Ecto.NoResultsError)
  """
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @doc """
  TODO
  """
  def get_user_by_user_name(user_name), do: Repo.get_by(User, user_name: user_name)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Changeset{}}

  """
  def create_user(email, password) when is_binary(email) and is_binary(password) do
    # TODO: Reduce this to 1 database transaction
    with {:ok, user} <-
           %User{}
           |> User.registration_changeset(%{email: email, password: password})
           |> Repo.insert(),
         {:ok, profile} <-
           %UserProfile{}
           |> UserProfile.changeset()
           |> Ecto.Changeset.put_assoc(:user, user)
           |> Repo.insert(),
         {auth_token, refresh_token, new_token_changeset} <- create_login_tokens(user),
         {:ok, _} <- set_user_online(user, new_token_changeset) do
      deliver_user_confirmation_instructions(user)
      {:ok, user, profile, auth_token, refresh_token}
    else
      changeset_or_error ->
        case changeset_or_error do
          {:error, reason} -> {:error, reason}
          changeset -> {:error, changeset}
        end
    end
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
      |> User.validate_current_password(user.hashed_password, password)
      |> User.validate_new_password(attrs[:password])

    password_reset = Keyword.get(opts, :password_reset, false)

    if password_reset,
      do: update_user_and_delete_tokens(changeset, user.id),
      else: Repo.update(changeset)
  end

  def update_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(user.hashed_password, password)
    |> update_user_and_delete_tokens(user.id)
  end

  defp update_user_and_delete_tokens(changeset, user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user_update, changeset)
    |> Ecto.Multi.delete_all(:delete_tokens, UserToken.user_tokens_by_context_query(user_id))
    |> Repo.transaction()
  end

  @doc """
  TODO
  """
  def update_user_name(user, attrs) do
    user
    |> User.user_name_changeset(attrs)
    |> Repo.update()
  end

  defp set_user_online(%User{id: user_id}, new_token_changeset) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:set_online, UserProfile.changeset_by_user_id(user_id, %{online: true}))
    |> Ecto.Multi.insert(:add_refresh_token, new_token_changeset)
    |> Repo.transaction()
  end

  @doc """
  Attempt to login by an email and password. If successful, create the auth and refresh token
  and store the refresh token in the database.
  """
  @spec login(String.t(), String.t()) ::
          {:ok, User.t(), UserProfile.t(), String.t(), String.t()}
          | {:error, :invalid_credentials}
  def login(email, password) do
    with user when not is_nil(user) <- Repo.get_by(User, email: email),
         true <- User.valid_password?(user.hashed_password, password),
         profile when not is_nil(profile) <- Repo.get_by(UserProfile, user_id: user.id),
         {auth_token, refresh_token, new_token_changeset} <- create_login_tokens(user),
         {:ok, _} = set_user_online(user, new_token_changeset) do
      {:ok, user, profile, auth_token, refresh_token}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  @doc """
  Although we cannot invalidate a specific token,
  we can invalidate all refresh tokens for the user.
  """
  def sign_out_all(%User{} = user) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :delete_refresh_tokens,
      UserToken.user_tokens_by_context_query(user.id, [:refresh_token])
    )
    |> Ecto.Multi.update(:set_user_offline, fn _ ->
      UserProfile.changeset_by_user_id(user.id, %{online: false})
    end)
    |> Repo.transaction()
  end

  @doc """
  Removes a specified refresh token for the user and sets them to offline if they have no active refresh tokens
  """
  @spec sign_out(String.t(), String.t()) ::
          {:ok, :signed_out | :remaining_signins} | {:error, :invalid_token}
  def sign_out(user_id, token) do
    # TODO: Can we make this into one query?
    with {:ok, hashed_token} <- UserToken.hash_token(token),
         refresh_tokens <-
           Repo.all(UserToken.get_active_user_tokens_for_context(user_id, :refresh_token)) do
      case length(refresh_tokens) do
        0 ->
          {:error, :invalid_token}

        1 ->
          [refresh_token] = refresh_tokens

          if refresh_token.token == hashed_token do
            delete_last_refresh_token(refresh_token)
          else
            {:error, :invalid_token}
          end

        2 ->
          case Enum.find(refresh_tokens, :no_token, &(&1.token == hashed_token)) do
            :no_token -> {:error, :invalid_token}
            _ -> delete_one_refresh_token(user_id, hashed_token)
          end
      end
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp delete_last_refresh_token(refresh_token) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete(:delete_token, refresh_token)
    |> Ecto.Multi.update(:set_user_offline, fn %{delete_token: %{user_id: user_id}} ->
      UserProfile.changeset_by_user_id(user_id, %{online: false})
    end)
    |> Repo.transaction()

    {:ok, :signed_out}
  end

  defp delete_one_refresh_token(user_id, hashed_token) do
    Repo.delete_all(UserToken.user_token_query(user_id, hashed_token))
    {:ok, :remaining_signins}
  end

  @spec use_refresh_token(String.t()) :: {:ok, String.t(), binary()} | {:error, :invalid_token}
  def use_refresh_token(token) do
    case UserToken.verify_hashed_token(token, :refresh_token) do
      {:ok, user, used_token} ->
        {auth_token, refresh_token, new_token_changeset} = create_login_tokens(user)

        Ecto.Multi.new()
        |> Ecto.Multi.delete(:used_token, used_token)
        |> Ecto.Multi.insert(:new_token, new_token_changeset)
        |> Repo.transaction()

        {:ok, auth_token, refresh_token}

      _ ->
        {:error, :invalid_token}
    end
  end

  defp create_login_tokens(%User{} = user) do
    auth_token = Token.generate_auth_token(user)
    {refresh_token, hashed_token} = UserToken.build_hashed_token()

    hashed_token_changeset =
      UserToken.new_changeset_from_token_context(hashed_token, :refresh_token, user)

    {auth_token, refresh_token, hashed_token_changeset}
  end

  def update_profile_by_user_id(user_id, attrs) do
    user_id
    |> UserProfile.changeset_by_user_id(attrs)
    |> Repo.update()
  end

  @spec confirm_user(String.t()) :: {:ok, User.t()} | {:error, :invalid_token}
  def confirm_user(token) do
    case UserToken.verify_hashed_token(token, :email_confirmation) do
      {:ok, user, _token} ->
        if user.confirmed_at do
          {:error, :already_confirmed}
        else
          Ecto.Multi.new()
          |> Ecto.Multi.update(:set_user_confirmed, User.confirm_email_changeset(user))
          |> Ecto.Multi.delete_all(
            :delete_email_confirmation_tokens,
            UserToken.user_tokens_by_context_query(user.id, [:email_confirmation])
          )
          |> Repo.transaction()
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  @spec confirm_token(String.t(), UserToken.token_type()) ::
          {:ok, User.t()} | {:error, :invalid_token}
  def confirm_token(token, context) do
    case UserToken.verify_hashed_token(token, context) do
      {:ok, user, _token} -> {:ok, user}
      _ -> {:error, :invalid_token}
    end
  end

  def deliver_user_confirmation_instructions(%User{} = user) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      send_email_with_hashed_token(:email_confirmation, user)
    end
  end

  def deliver_user_email_change_instructions(%User{} = user) do
    send_email_with_hashed_token(:email_change, user)
  end

  def deliver_user_password_reset_instructions(%User{} = user) do
    send_email_with_hashed_token(:password_reset, user)
  end

  @spec form_url(UserToken.token_type(), String.t()) :: String.t()
  def form_url(context, token) do
    frontend_url = Application.fetch_env!(:chat_api, ChatApi.Account)[:frontend_url]
    "#{frontend_url}/#{to_string(context)}?token=#{token}"
  end

  @spec send_email_with_hashed_token(UserNotifier.limited_token_type(), User.t()) :: {:ok}
  defp send_email_with_hashed_token(context, user) do
    {confirm_token, hashed_token} = UserToken.build_hashed_token()
    IO.inspect(context)
    IO.inspect(confirm_token)

    hashed_token_changeset =
      UserToken.new_changeset_from_token_context(hashed_token, context, user)

    Repo.insert(hashed_token_changeset)

    url = form_url(context, confirm_token)
    UserNotifier.deliver_email(context, user, url)
  end
end
