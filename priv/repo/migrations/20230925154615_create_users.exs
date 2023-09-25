defmodule ChatApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  execute "CREATE EXTENSION IF NOT EXISTS citext", ""
  def change do
    create table(:users) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :user_name, :string, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
    end

    create unique_index(:users, [:email])
  end
end
