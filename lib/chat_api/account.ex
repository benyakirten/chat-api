defmodule ChatApi.Account do
  @moduledoc """
  The Account context.
  TODO: Make sure everything fails spectacularly - error handler will take care of it
  """

  alias ChatApi.Serializer
  alias ChatApi.Chat.Conversation
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
  Creates a user.

  TODO: Update docs
  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Changeset{}}

  """
  def create_user(email, password, display_name \\ nil)
      when is_binary(email) and is_binary(password) do
    # TODO: Reduce this to 1 database transaction
    # Multiple database transactions is not only inefficient but error prone
    transaction =
      Ecto.Multi.new()
      |> multi_insert_user(email, password, display_name || email)
      |> multi_insert_profile()
      |> multi_create_tokens()

    case Repo.transaction(transaction) do
      {:ok, %{user: user, profile: profile, tokens: {auth_token, refresh_token}}} ->
        deliver_user_confirmation_instructions(user)
        {:ok, user, profile, auth_token, refresh_token}

      {:error, reason} ->
        {:error, reason}

      changeset ->
        {:error, changeset}
    end
  end

  defp multi_insert_user(changeset, email, password, display_name) do
    Ecto.Multi.insert(
      changeset,
      :user,
      %User{}
      |> User.registration_changeset(%{
        email: email,
        password: password,
        display_name: display_name
      })
    )
  end

  defp multi_insert_profile(changeset) do
    Ecto.Multi.run(changeset, :profile, fn _repo, %{user: user} ->
      %UserProfile{}
      |> UserProfile.changeset()
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Repo.insert()
    end)
  end

  defp multi_create_tokens(changeset) do
    Ecto.Multi.run(changeset, :tokens, fn _repo, %{user: user} ->
      {auth_token, refresh_token, new_token_changeset} = create_login_tokens(user)

      case Repo.insert(new_token_changeset) do
        {:ok, _} -> {:ok, {auth_token, refresh_token}}
        error -> error
      end
    end)
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

  def update_display_name(user_id, display_name) do
    transaction =
      Ecto.Multi.new()
      |> Ecto.Multi.one(:get_user, User.user_with_different_name_query(user_id, display_name))
      |> Ecto.Multi.run(:update_user, fn _repo, %{get_user: user} ->
        case user do
          user when is_nil(user) ->
            {:error, :no_user}

          user ->
            User.display_name_changeset(user, %{display_name: display_name})
            |> Repo.update()
        end
      end)

    case Repo.transaction(transaction) do
      {:ok, changes} -> {:ok, changes[:update_user]}
      {:error, _changes, error, _change_atoms} -> {:error, error}
    end
  end

  @doc """
  Attempt to login by an email and password. If successful, create the auth and refresh token
  and store the refresh token in the database.
  """
  @spec login(String.t(), String.t()) ::
          {:ok, User.t(), UserProfile.t(), [Conversation.t()], [User.t()], String.t(), String.t()}
          | {:error, any}
  def login(email, password) do
    transaction =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:user, fn _repo, _changes ->
        with user when not is_nil(user) <- Repo.one(User.user_by_email_query(email)),
             true <- User.valid_password?(user.hashed_password, password) do
          {:ok, user}
        else
          _ -> {:error, :invalid_credentials}
        end
      end)
      |> Ecto.Multi.run(:conversations, fn _repo, %{user: user} ->
        {:ok, Repo.all(Conversation.user_conversations_query(user.id))}
      end)
      |> Ecto.Multi.run(
        :conversation_users,
        fn _repo, %{conversations: conversations, user: user} ->
          unique_users =
            Repo.all(Conversation.unique_users_for_conversations_query(conversations, user.id))

          {:ok, unique_users}
        end
      )
      |> multi_create_tokens()

    case Repo.transaction(transaction) do
      {:ok,
       %{
         user: user,
         tokens: {auth_token, refresh_token},
         conversations: conversations,
         conversation_users: users
       }} ->
        {:ok, user, user.profile, conversations, users, auth_token, refresh_token}

      _ ->
        {:error, :invalid_credentials}
    end
  end

  @doc """
  If the user wants to force all clients connected with their account to reconnect
  """
  @spec sign_out_all(String.t()) :: any()
  def sign_out_all(user_id) do
    Repo.delete_all(UserToken.user_tokens_by_context_query(user_id, [:refresh]))
  end

  @spec use_refresh_token(String.t()) ::
          {:ok, User.t(), UserProfile.t(), [Conversation.t()], [User.t()], String.t(), binary()}
          | {:error, :invalid_token}
  def use_refresh_token(token) do
    transaction =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:verify_token, fn _repo, _changes ->
        case UserToken.verify_hashed_token(token, :refresh) do
          {:ok, user, used_token} -> {:ok, {user, used_token}}
          _ -> {:error, :invalid_token}
        end
      end)
      |> Ecto.Multi.run(:delete_used_token, fn _repo, %{verify_token: {user, used_token}} ->
        {auth_token, refresh_token, new_token_changeset} = create_login_tokens(user)

        with {:ok, _} <- Repo.delete(used_token),
             {:ok, _} <- Repo.insert(new_token_changeset) do
          {:ok, {auth_token, refresh_token}}
        else
          {:error, reason} -> {:error, reason}
        end
      end)
      |> Ecto.Multi.run(:get_profile, fn _repo, %{verify_token: {user, _}} ->
        case Repo.one(UserProfile.profile_by_user_id_query(user.id)) do
          profile when not is_nil(profile) -> {:ok, profile}
          _ -> {:error, :missing_profile}
        end
      end)
      |> Ecto.Multi.run(:conversations, fn _repo, %{verify_token: {user, _}} ->
        {:ok, Repo.all(Conversation.user_conversations_query(user.id))}
      end)
      |> Ecto.Multi.run(
        :conversation_users,
        fn _repo, %{conversations: conversations, verify_token: {user, _token}} ->
          unique_users =
            Repo.all(Conversation.unique_users_for_conversations_query(conversations, user.id))

          {:ok, unique_users}
        end
      )

    case Repo.transaction(transaction) do
      {:ok,
       %{
         verify_token: {user, _},
         delete_used_token: {auth_token, refresh_token},
         get_profile: profile,
         conversations: conversations,
         conversation_users: users
       }} ->
        {:ok, user, profile, conversations, users, auth_token, refresh_token}

      _ ->
        {:error, :invalid_token}
    end
  end

  defp create_login_tokens(%User{} = user) do
    auth_token = Token.generate_auth_token(user)
    {refresh_token, hashed_token} = UserToken.build_hashed_token()

    hashed_token_changeset =
      UserToken.new_changeset_from_token_context(hashed_token, :refresh, user)

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

  @spec send_email_with_hashed_token(UserNotifier.limited_token_type(), User.t()) :: :ok
  defp send_email_with_hashed_token(context, user) do
    {confirm_token, hashed_token} = UserToken.build_hashed_token()
    # TODO: Remove these lines once notifier works correctly
    IO.inspect(context)
    IO.inspect(confirm_token)

    hashed_token_changeset =
      UserToken.new_changeset_from_token_context(hashed_token, context, user)

    Repo.insert(hashed_token_changeset)

    url = form_url(context, confirm_token)
    UserNotifier.deliver_email(context, user, url)
    :ok
  end

  def set_user_profile_recents(user_id, recents) do
    transaction =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:create_changeset, fn _repo, _changes ->
        case UserProfile.changeset_by_user_id(user_id, %{recents: recents}) do
          {:error, :not_found} -> {:error, :not_found}
          changeset -> {:ok, changeset}
        end
      end)
      |> Ecto.Multi.run(:update_changeset, fn _repo, %{create_changeset: changeset} ->
        Repo.update(changeset)
      end)
      |> Repo.transaction()

    case transaction do
      {:error, _change_atom, error, _changes} -> {:error, error}
      {:ok, changes} -> {:ok, changes[:update_changeset]}
    end
  end

  @doc """
  Removes a specified refresh token for the user
  """
  @spec sign_out(String.t(), String.t()) ::
          {:ok, :signed_out} | {:error, :invalid_token}
  def sign_out(user_id, token) do
    transaction =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:verify_token, fn _repo, _changesets ->
        case UserToken.verify_hashed_token(token, :refresh) do
          {:ok, user, token} when user.id == user_id ->
            {:ok, token.token}

          _ ->
            {:error, :invalid_token}
        end
      end)
      |> Ecto.Multi.run(:delete_token, fn _repo, %{verify_token: hashed_token} ->
        case Repo.delete_all(UserToken.user_token_query(user_id, hashed_token)) do
          {1, _} -> {:ok, :deleted}
          _ -> {:error, :unable_to_delete}
        end
      end)

    case Repo.transaction(transaction) do
      {:ok, _} -> {:ok, :signed_out}
      {:error, _changes, _error, _change_atoms} -> {:error, :invalid_token}
    end
  end

  @spec search_users(map()) :: {[User.t()], binary()}
  def search_users(opts \\ %{}) do
    {query, page_size} = User.search_users_query(opts)
    users = Repo.all(query)

    page_token =
      with true <- length(users) > page_size, {:ok, last_user} <- Enum.fetch(users, -1) do
        Serializer.get_next_token(last_user)
      else
        _ -> ""
      end

    {users, page_token}
  end
end
