defmodule ChatApi.Account.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:email, :string)
    field(:user_name, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:confirmed_at, :naive_datetime)

    timestamps()
  end


  # TODO: Get types working
  # @type user :: Ecto.Changeset.t(
  #   id: String.t(),
  #   email: String.t(),
  #   user_name: String.t(),
  #   password: String.t(),
  #   hashed_password: String.t(),
  #   confirmed_at: NaiveDateTime.t() | nil,
  #   inserted_at: NaiveDateTime.t(),
  #   updated_at: NaiveDateTime.t(),
  # )

  @doc """
  Register (or change a registration of) a user given
  an email, user name and password.
  There are the following requirements:
  1. The email needs to be unique and be a valid email address (RFC 5322 used for checking)
  2. The password must be between 12 and 72 characters,
    have 1 uppercase and 1 lowercase letter, a number and one of the following: !@#$%^&*+`~'
  3. Hashes the password

  If a user name is not specified, the email is used as a default value.

  TODO: Add doc tests
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
    |> validate_length(:email, max: 160)
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
    |> validate_format(:password, ~r"!@#$%^&*+`~']", message: "must contain at least one of the following characters: !@#$%^&*+`~'")
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
      user_name = case get_change(changeset, :user_name) do
        name when is_binary(name) -> name
        _ -> get_change(changeset, :email)
      end

      changeset
      |> put_change(:user_name, user_name)
      |> validate_required([:user_name])
      # These are arbitrary - we may want to change them
      |> validate_length(:user_name, min: 3, max: 20)
  end

  def valid_password?(%ChatApi.Account.User{hashed_password: hashed_password}, password)
    when is_binary(hashed_password) and byte_size(password) > 0
   do
    Argon2.verify_pass(password, hashed_password)
  end

  def valid_password(_, _) do
    Argon2.no_user_verify()
    false
  end
end
