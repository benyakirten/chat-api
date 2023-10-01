defmodule ChatApi.Account.UserProfile do
  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias ChatApi.Account.{User, UserProfile}
  alias ChatApi.Repo

  @type t :: %__MODULE__{
          user_name: String.t(),
          hidden: :boolean,
          theme: String.t(),
          magnification: Decimal.t()
        }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "user_profiles" do
    field(:user_name, :string)
    field(:hidden, :boolean)
    field(:theme, :string)
    field(:magnification, :decimal)

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:user_name, :hidden, :theme, :magnification])
    |> validate_number(:magnification,
      greater_than_or_equal_to: 0.7,
      less_than_or_equal_to: 1.4,
      message: "must be a number between 0.7 and 1.4"
    )
    |> validate_format(:theme, ~r/^auto|day|night$/,
      message: "must be one of either 'auto', 'night' or 'auto'"
    )
  end

  @doc """
  Create a new profile for a user with certain defaults.
  """
  @spec new_profile_changeset(String.t(), User.t()) :: Ecto.Changeset.t()
  def new_profile_changeset(user_name, user) do
    %UserProfile{}
    |> cast(
      %{user_name: user_name, magnification: 1.0, theme: "auto", hidden: false},
      [:user_name, :magnification, :theme, :hidden]
    )
    |> put_assoc(:user_id, user)
  end

  def changeset_by_user_id(user_id, attrs) do
    case Repo.one(from p in UserProfile, where: p.user_id == ^user_id) do
      nil -> {:error, :not_found}
      profile -> changeset(profile, attrs)
    end
  end

  @doc """
  A user changeset for changing the user_name.

  It requires the user name to change otherwise an error is added.
  """
  def username_changeset(user, attrs) do
    user
    |> cast(attrs, [:user_name])
    |> validate_length(:user_name, min: 3, max: 20)
    |> case do
      %{changes: %{user_name: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :user_name, "did not change")
    end
  end
end
