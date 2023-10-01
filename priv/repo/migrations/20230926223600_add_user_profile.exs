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

    create table(:user_profiles) do
      add(:hidden, :boolean, null: false, default: false)
      add(:theme, :string, null: false, default: "auto")
      add(:magnification, :decimal, scale: 1, precision: 2, null: false, default: 1.0)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all))

      timestamps()
    end

    create(index(:user_profiles, [:user_id]))
  end
end
