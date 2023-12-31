defmodule ChatApi.Account.UserProfile do
  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias ChatApi.Account.{User, UserProfile}
  alias ChatApi.Repo

  @type t :: %__MODULE__{
          hidden: :boolean,
          theme: String.t(),
          magnification: Decimal.t()
        }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "user_profiles" do
    field(:hidden, :boolean, default: false)
    field(:theme, :string, default: "auto")
    field(:magnification, :decimal, default: 1.0)
    field(:recents, {:array, :string}, default: [])

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:theme, :magnification, :recents, :hidden])
    |> validate_number(:magnification,
      greater_than_or_equal_to: 0.7,
      less_than_or_equal_to: 1.4,
      message: "must be a number between 0.7 and 1.4"
    )
    |> validate_format(:theme, ~r/^auto|day|night$/,
      message: "must be one of either 'auto', 'night' or 'auto'"
    )
  end

  def changeset_by_user_id(user_id, attrs) do
    case Repo.one(from(p in UserProfile, where: p.user_id == ^user_id)) do
      nil -> {:error, :not_found}
      profile -> changeset(profile, attrs)
    end
  end

  def profile_by_user_id_query(user_id) do
    from(p in UserProfile, where: p.user_id == ^user_id)
  end
end
