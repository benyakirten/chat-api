defmodule ChatApi.Repo.Migrations.AddUserProfile do
  use Ecto.Migration

  def change do
    create table(:block_list, primary_key: false) do
      add(:blocker_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:blocked_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
    end

    create(index(:block_list, [:blocker_id]))
    create(index(:block_list, [:blocked_id]))
    create(unique_index(:block_list, [:blocker_id, :blocked_id]))

    create table(:profile, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:online, :boolean)
      add(:hidden, :boolean)
      add(:theme, :string)
      add(:magnification, :float)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all))

      timestamps()
    end

    create(index(:profile, [:user_id]))
  end
end
