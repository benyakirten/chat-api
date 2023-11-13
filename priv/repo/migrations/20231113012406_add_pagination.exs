defmodule ChatApi.Repo.Migrations.AddPagination do
  use Ecto.Migration

  def change do
    create(index(:users, [:inserted_at, :id]))
    create(index(:conversations, [:inserted_at, :id]))
    create(index(:messages, [:inserted_at, :id]))
  end
end
