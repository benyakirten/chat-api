defmodule ChatApi.Repo.Migrations.AddPagination do
  use Ecto.Migration

  def change do
    create(index(:users, ["inserted_at DESC", "id DESC"]))
    create(index(:conversations, ["inserted_at DESC", "id DESC"]))
    create(index(:messages, ["inserted_at DESC", "id DESC"]))
  end
end
