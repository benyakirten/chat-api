defmodule ChatApi.Account.UserProfile do
  use Ecto.Schema
  import Ecto.Changeset

  alias ChatApi.Account.User

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "user_profiles" do
    field(:online, :boolean, default: true)
    field(:hidden, :boolean, default: false)
    field(:theme, :string, default: "auto")
    field(:magnification, :float, default: 1.0)

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:online, :hidden, :theme, :magnification])
    |> validate_number(:magnification, min: 0.7, max: 1.4)
    |> validate_format(:theme, ~r/auto|day|night/)
  end
end
