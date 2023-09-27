defmodule ChatApi.Account.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias ChatApi.Account.{UserProfile, UserToken}
  alias ChatApi.Chat.Conversation

  @type t :: %__MODULE__{
          email: String.t(),
          user_name: String.t(),
          password: String.t() | nil,
          hashed_password: binary() | nil,
          confirmed_at: NaiveDateTime
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:email, :string)
    field(:user_name, :string)
    field(:password, :string, virtual: true)
    field(:hashed_password, :string)
    field(:confirmed_at, :naive_datetime)

    has_many(:users_tokens, UserToken)
    has_one(:user_profiles, UserProfile)
    many_to_many(:conversations, Conversation, join_through: :users_conversations)

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

  If a user name is not specified, the email is used as a default value.

  TODO: Add regular tests and doc tests
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email()
    |> validate_password()
    |> assign_user_name()
  end

  @email_regex ~r<(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])>
  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, @email_regex, message: "must be a valid email")
    |> validate_length(:email, max: 160, message: "must be at most 160 characters long")
    |> unsafe_validate_unique(:email, ChatApi.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
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

  defp assign_user_name(changeset) do
    # Get a default value for a username
    user_name =
      case get_change(changeset, :user_name) do
        name when is_binary(name) -> name
        _ -> get_change(changeset, :email)
      end

    changeset
    |> put_change(:user_name, user_name)
    |> validate_user_name()
  end

  defp validate_user_name(changeset) do
    changeset
    |> validate_required([:user_name])
    # These are arbitrary - we may want to change them
    |> validate_length(:user_name, min: 3, max: 20)
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

  def user_name_changeset(user, attrs) do
    user
    |> cast(attrs, [:user_name])
    |> validate_user_name()
    |> case do
      %{changes: %{user_name: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the user_name.

  It requires the user name to change otherwise an error is added.
  """
  def username_changeset(user, attrs) do
    user
    |> cast(attrs, [:user_name])
    |> validate_user_name()
    |> case do
      %{changes: %{user_name: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :user_name, "did not change")
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
end
