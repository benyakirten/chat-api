defmodule ChatApi.Account.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias ChatApi.Account.{UserProfile, UserToken, User}
  alias ChatApi.Chat.{Conversation, EncryptionKey}
  alias ChatApi.Pagination

  @type t :: %__MODULE__{
          email: String.t(),
          password: String.t() | nil,
          hashed_password: binary() | nil,
          confirmed_at: NaiveDateTime | nil,
          display_name: String.t()
        }
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:confirmed_at, :naive_datetime)
    field(:display_name, :string)

    has_many(:tokens, UserToken)
    has_many(:encryption_keys, EncryptionKey)
    has_one(:profile, UserProfile)

    many_to_many(:conversations, Conversation,
      join_through: "users_conversations",
      on_replace: :delete
    )

    timestamps()
  end

  # TODO: Get types working

  @doc """
  Register (or change a registration of) a user given
  an email, user name and password.
  There are the following requirements:
  1. The email needs to be unique and be a valid email address (RFC 5322 used for checking)
  2. The password must be between 12 and 72 characters,
    have 1 uppercase and 1 lowercase letter, a number and one of the following: !@#$%^&*+`~'
  3. Hashes the password

  TODO: Add regular tests and doc tests
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :display_name])
    |> validate_required([:email, :password, :display_name])
    |> validate_length(:display_name, min: 3, max: 20)
    |> validate_email()
    |> validate_password()
  end

  @spec user_by_email_query(binary()) :: Ecto.Query.t()
  def user_by_email_query(email) do
    from(u in User, where: u.email == ^email, preload: [:profile])
  end

  def user_by_id_query(id), do: from(u in User, where: u.id == ^id)
  def users_by_ids_query(user_ids), do: from(u in User, where: u.id in ^user_ids)

  @email_regex ~r<(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])>
  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, @email_regex, message: "must be a valid email")
    |> validate_length(:email, max: 160, message: "must be at most 160 characters long")
    |> unsafe_validate_unique(:email, ChatApi.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 12, max: 72)
    # TODO: Combine these into one regex
    |> validate_format(:password, ~r/[a-z]/, message: "must contain a lowercase letter")
    |> validate_format(:password, ~r/[A-Z]/, message: "must contain an uppercase letter")
    |> validate_format(:password, ~r/[0-9]/, message: "must contain at least one number")
    |> validate_format(:password, ~r"[!@#$%^&*+`~']",
      message: "must contain at least one of the following characters: !@#$%^&*+`~'"
    )
    |> hash_password()
  end

  defp hash_password(changeset) do
    password = get_change(changeset, :password)

    changeset
    |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  @doc """
  Checks if the user's hashed password matches the password attempt when it is hashed.
  """
  def valid_password?(hashed_password, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Argon2.verify_pass(password, hashed_password)
  end

  def valid_password(_, _) do
    Argon2.no_user_verify()
    false
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  Creates a password changeset that requires both password and password_confirmation values to be present
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password()
  end

  @doc """
  Checks to see if the password is valid and
  """
  def validate_current_password(changeset, hashed_password, password) do
    if valid_password?(hashed_password, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  @doc """
  Make sure that the new password does not match the old password.
  """
  def validate_new_password(changeset, new_password) do
    if not valid_password?(changeset.data.hashed_password, new_password) do
      changeset
    else
      add_error(changeset, :new_password, "did not change")
    end
  end

  def confirm_email_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  def display_name_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name])
    |> validate_required([:display_name])
    |> validate_length(:display_name, min: 3, max: 20)
  end

  @spec multiple_users_by_id_query([binary()]) :: Ecto.Query.t()
  def multiple_users_by_id_query(user_ids) do
    from(u in User, where: u.id in ^user_ids)
  end

  def user_with_different_name_query(user_id, display_name) do
    from(u in User, where: u.id == ^user_id and u.display_name != ^display_name)
  end

  @doc """
  Get a paginated group of users. Parameters for the opts are:
  1. search - search the display_name or email for the text value (case insensitive)
  2. page_size - specify a page size (default 20)
  3. page_token - a pagination token to specify where the searching starts from

  ## Examples

      iex> {query, page_size} = search_users_query(%{"search" => "john", "page_size" => 5, "page_token" => "eyJpZCI6IjZmOWI2YzEzLWU0MGYtNGQ5MS05ODkwLTllODE5NmMxOGY5ZSIsImluc2VydGVkX2F0IjoiMjAyMy0xMS0xMyAwMjowNTo0NCJ9"})
      iex> Repo.all(query)
      [%User{}, ...]
  """
  @spec search_users_query(binary(), map() | nil) :: {Ecto.Query.t(), number()}
  def search_users_query(user_id, opts \\ %{}) do
    search_string = Pagination.get_search_string(opts)
    page_size = Pagination.get_page_size(opts)

    query =
      from(u in User,
        where:
          ilike(u.email, ^search_string) or
            ilike(u.display_name, ^search_string)
      )
      |> where([u], u.id != ^user_id)
      |> Pagination.add_seek_pagination(page_size)
      |> Pagination.paginate_from(opts)

    {query, page_size}
  end
end
