defmodule :"Elixir.ChatApi.Repo.Migrations.Add-encryption-keys" do
  use Ecto.Migration

  def change do
    # JWK encoded crypto key
    # https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/importKey#json_web_key
    """
    Example of the such a key for the RSA-OAEP algorithm with sha256 hashing:
    {
      alg: "RSA-OAEP-256",
      d: "AlLh-5E74d0TRf0lBcKU25LSwgG43jmdOEGivbsDHHmastztsV-0TurL0mPYaGI4pDGHLU_D0VywR48dCJdQKALCDLbGIBzKBmrNBwknGRlnZ033Paz-qzzUMxNNPCGpI7nBbfUNwmWSHlgMUijuiEEfPOGXfTXXXIdEzjFCgOV7oin7bdoH4mkph506cdgyOpHFkVHPCHc8zKEJtaVI3HNmIORALgMOVtTIMECAiCa_pk2Cyp4g9t8n7Pt4z7HyOaAt-x9YjzRSIFAfa5jwx-WDjh9U7_Yz4hjkLdzlS-FKahsaoazrM7kOimHlXeVpqJjWfkfdywXB7iW2PLN80Q",
      dp: "rjW9YW8GLTCcKuZGI4sRPsM8qxpsSMA3slbYTRkGFEuHzjWTHxlh5WCD-2VUgsVMGhoyHriI56OZB-a6jyGgR7f7VOWANX_iAIAfyYeFzIFN03aMyPd0iXJpYYvLXTWduQYQoPKbFPCJWY2c4j2NKmT_nPxxL40uZMzJolTXhBc",
      dq: "J0ZKhhaxbGdTiSKfezDZ9-AWs4MV5AIKt4GpGKGhA-fFjY7CpDob6w8cU8ZN34HIov8_Eurl7PlNQFrH7EVhQlakEAxtF9h6tq_U1kKw9paoF9aiic5mVe2X5pePnN3qUu0CRJcEJQpQsMF02KEa908CC9W-23pbhNxHtJdwH50",
      e: "AQAB",
      ext: true,
      key_ops: ["decrypt"],
      kty: "RSA",
      n: "xK_-u1kujmRR4AUm726iP1_90X42BDivMI3uyWmDIv_qbXTA5yU1Y6XXZPeq3kuIczVyrLW_ALv2EY8G5IfmFP14LHtdh6uwMrelKkkQzbjAL9_HZDX1fyw2YVKqOjP_g4H84dYnHaEjfZlY9dWH2tr9o7LZoQe_CS66lDywCjRfzYHzuaK8NCStb8nmBqTbNBb6rr2F6hyynf9hrv8r22R0QDWxR0Ci8bs81r37LFU1owc5_BBZSjsOGd1S3o-Df3j_hOz8LGewtrYpZuRxhM1yDM9AVlbS1dUdapPpmldrfJqOrY-L9mNQzIFN-2Uy41PgH-V8CCwMtmF0CN7r4Q",
      p: "6nkY8-I9q7ePTJZYzrp8M1trHzVlgDcvMDf-t4XVhDItbD3wg-FH44nXVqz1Wq80AjL82wnYXtNc2Ux-JWGckWv_lYKIMZarh-kUQUssJZNMlBfeunt2fc4ER4HY9q8JBRUzje5IWbCSgQW6RnOru8_fn-pfMOQJEwBVYELCDn8",
      q: "1r7PcH-gYZScArHMm6qBng1h8L7jJaG9exMFjzOCMKDQ6X6-fnT1_I_bJ5Gn3y-3p6jnDpvDK0FcbmFQajiW3mFGJ7yeJG2UbAqrQJ63yzG8j6vQVnpts_aOVdlCsImHpJKLCJ0KozrFrBCxkwd3fKVtX0vLOoE9HFEWh7wYlZ8",
      qi: "ZAMdPoABaijJPVmigSSI3yC9U0BpPzqgnDIljiy4JN7FuS4wJ1q04miWp_RCG6H4PkBa0OC_SEhLwWqMJWx3yW-8r3dqQKCXDBF4LPVSLYTZS3OJcXSy7T4pijNuv1qGUouY-I1NuXZHK29041QJzyw8LFS1E67CM2_cSZN2q2Y",
    }
    """

    create table(:encryption_keys) do
      add(:alg, :string, null: false)
      add(:d, :string, null: false)
      add(:dp, :string, null: false)
      add(:e, :string, null: false)
      add(:ext, :boolean, null: false)
      add(:key_ops, {:array, :string}, null: false)
      add(:kty, :string, null: false)
      add(:n, :string, null: false)
      add(:p, :string, null: false)
      add(:q, :string, null: false)
      add(:qi, :string, null: false)
      add(:type, :string, null: false)

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
