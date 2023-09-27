defmodule ChatApi.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :private, :boolean, default: false, null: false
      add :alias, :string

      timestamps()
    end

    create table(:users_conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false)

      timestamps(updated_at: false)
    end

    create index(:users_conversations, [:conversation_id])
    create index(:users_conversations, [:user_id])
    create unique_index(:users_conversations, [:user_id, :conversation_id])
  end
end
