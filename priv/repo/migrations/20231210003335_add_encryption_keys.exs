defmodule :"Elixir.ChatApi.Repo.Migrations.Add-encryption-keys" do
  use Ecto.Migration

  def change do
    # JWK encoded crypto key
    # https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/importKey#json_web_key

    create table(:encryption_keys) do
      # Private keys do not a d, dp, dq, p, q or qi field.
      # TODO: Consider if these should be two different tables.
      add(:alg, :text, null: false)
      add(:d, :binary)
      add(:dp, :binary)
      add(:dq, :binary)
      add(:e, :binary, null: false)
      add(:ext, :boolean, null: false)
      add(:key_ops, {:array, :text}, null: false)
      add(:kty, :text, null: false)
      add(:n, :binary, null: false)
      add(:p, :binary)
      add(:q, :binary)
      add(:qi, :binary)
      add(:type, :text, null: false)

      # This table has the foreign keys so we can cascade the delete.
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)

      add(:conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      timestamps()
    end

    create(index(:encryption_keys, [:type]))

    # Between the constraint and the unique index, we can enforce that a user can only have a private and public key.
    create(unique_index(:encryption_keys, [:user_id, :conversation_id, :type]))

    create(
      constraint(:encryption_keys, :public_or_private_type,
        check: "type = 'private' or type = 'public'"
      )
    )
  end
end
