defmodule ChatApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    create table(:users) do
      add(:email, :citext, null: false)
      add(:display_name, :string, null: false)
      add(:hashed_password, :string, null: false)
      add(:confirmed_at, :naive_datetime)

      timestamps()
    end

    create(
      constraint(
        :users,
        "display_name_between_3_and_20",
        check: "length(display_name) >= 3 and length(display_name) <= 20"
      )
    )

    create(unique_index(:users, [:email]))
    create(index(:users, [:display_name]))
  end
end
