defmodule ChatApi.Repo.Migrations.AddTokensTable do
  use Ecto.Migration

  def change do
    create table(:users_tokens, primary_key: false) do
      # add :id, :binary_id, primary_key: true
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:token, :binary, null: false)
      # Indicate whether it's an email reset token, password reset token, refresh token, etc.
      add(:context, :string, null: false)

      timestamps(updated_at: false)
    end

    create(index(:users_tokens, [:user_id]))
    create(unique_index(:users_tokens, [:context, :token]))
  end
end
