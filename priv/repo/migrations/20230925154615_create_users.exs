defmodule ChatApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    create table(:users, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:email, :citext, null: false)
      add(:user_name, :string, null: false)
      add(:hashed_password, :string, null: false)
      add(:confirmed_at, :naive_datetime)

      timestamps()
    end

    create(index(:users, [:user_name]))
    create(unique_index(:users, [:email]))
  end
end
