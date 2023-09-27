defmodule ChatApi.Account.UserProfile do
  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias ChatApi.Account.{User, UserProfile}
  alias ChatApi.Repo

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "user_profiles" do
    field(:online, :boolean, default: true)
    field(:hidden, :boolean, default: false)
    field(:theme, :string, default: "auto")
    field(:magnification, :decimal, default: 1.0)

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:online, :hidden, :theme, :magnification])
    |> validate_number(:magnification, greater_than_or_equal_to: 0.7, less_than_or_equal_to: 1.4)
    |> validate_format(:theme, ~r/auto|day|night/)
  end

  def changeset_by_user_id(user_id, attrs) do
    case Repo.one(from p in UserProfile, join: u in assoc(p, :user), where: u.id == ^user_id) do
      nil -> {:error, :not_found}
      profile -> changeset(profile, attrs)
    end
  end
end
