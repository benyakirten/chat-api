defmodule ChatApi.Repo.Migrations.CreateMessageGroups do
  use Ecto.Migration

  def change do
    create table(:message_groups) do
      add(:user_id, references(:users, on_delete: :delete_all))
      add(:conversation_id, references(:conversations, on_delete: :delete_all))
    end

    create(index(:message_groups, [:user_id]))
    create(index(:message_groups, [:conversation_id]))

    alter table(:messages) do
      add(:message_group_id, references(:message_groups, on_delete: :delete_all))
    end

    create(index(:messages, [:message_group_id]))
  end
end
