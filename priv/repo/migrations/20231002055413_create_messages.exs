defmodule ChatApi.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add(:content, :text)
      add(:recipient_user_id, references(:users, on_delete: :delete_all))

      timestamps()
    end

    create(index(:messages, [:recipient_user_id]))
  end
end
