defmodule ChatApi.Chat.EncryptionKey do
  alias ChatApi.Chat.EncryptionKey
  alias ChatApi.Chat.Conversation
  alias ChatApi.Account.User
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  @typedoc """
  The JWK encrypted public or private key data.
  An example of data given might be:
  ```
  %{
  "alg" => "RSA-OAEP-256",
  "d" =>
    "AlLh-5E74d0TRf0lBcKU25LSwgG43jmdOEGivbsDHHmastztsV-0TurL0mPYaGI4pDGHLU_D0VywR48dCJdQKALCDLbGIBzKBmrNBwknGRlnZ033Paz-qzzUMxNNPCGpI7nBbfUNwmWSHlgMUijuiEEfPOGXfTXXXIdEzjFCgOV7oin7bdoH4mkph506cdgyOpHFkVHPCHc8zKEJtaVI3HNmIORALgMOVtTIMECAiCa_pk2Cyp4g9t8n7Pt4z7HyOaAt-x9YjzRSIFAfa5jwx-WDjh9U7_Yz4hjkLdzlS-FKahsaoazrM7kOimHlXeVpqJjWfkfdywXB7iW2PLN80Q",
  "dp" =>
    "rjW9YW8GLTCcKuZGI4sRPsM8qxpsSMA3slbYTRkGFEuHzjWTHxlh5WCD-2VUgsVMGhoyHriI56OZB-a6jyGgR7f7VOWANX_iAIAfyYeFzIFN03aMyPd0iXJpYYvLXTWduQYQoPKbFPCJWY2c4j2NKmT_nPxxL40uZMzJolTXhBc",
  "dq" =>
    "J0ZKhhaxbGdTiSKfezDZ9-AWs4MV5AIKt4GpGKGhA-fFjY7CpDob6w8cU8ZN34HIov8_Eurl7PlNQFrH7EVhQlakEAxtF9h6tq_U1kKw9paoF9aiic5mVe2X5pePnN3qUu0CRJcEJQpQsMF02KEa908CC9W-23pbhNxHtJdwH50",
  "e" => "AQAB",
  "ext" => true,
  "key_ops" => ["decrypt"],
  "kty" => "RSA",
  "n" =>
    "xK_-u1kujmRR4AUm726iP1_90X42BDivMI3uyWmDIv_qbXTA5yU1Y6XXZPeq3kuIczVyrLW_ALv2EY8G5IfmFP14LHtdh6uwMrelKkkQzbjAL9_HZDX1fyw2YVKqOjP_g4H84dYnHaEjfZlY9dWH2tr9o7LZoQe_CS66lDywCjRfzYHzuaK8NCStb8nmBqTbNBb6rr2F6hyynf9hrv8r22R0QDWxR0Ci8bs81r37LFU1owc5_BBZSjsOGd1S3o-Df3j_hOz8LGewtrYpZuRxhM1yDM9AVlbS1dUdapPpmldrfJqOrY-L9mNQzIFN-2Uy41PgH-V8CCwMtmF0CN7r4Q",
  "p" =>
    "6nkY8-I9q7ePTJZYzrp8M1trHzVlgDcvMDf-t4XVhDItbD3wg-FH44nXVqz1Wq80AjL82wnYXtNc2Ux-JWGckWv_lYKIMZarh-kUQUssJZNMlBfeunt2fc4ER4HY9q8JBRUzje5IWbCSgQW6RnOru8_fn-pfMOQJEwBVYELCDn8",
  "q" =>
    "1r7PcH-gYZScArHMm6qBng1h8L7jJaG9exMFjzOCMKDQ6X6-fnT1_I_bJ5Gn3y-3p6jnDpvDK0FcbmFQajiW3mFGJ7yeJG2UbAqrQJ63yzG8j6vQVnpts_aOVdlCsImHpJKLCJ0KozrFrBCxkwd3fKVtX0vLOoE9HFEWh7wYlZ8",
  "qi" =>
    "ZAMdPoABaijJPVmigSSI3yC9U0BpPzqgnDIljiy4JN7FuS4wJ1q04miWp_RCG6H4PkBa0OC_SEhLwWqMJWx3yW-8r3dqQKCXDBF4LPVSLYTZS3OJcXSy7T4pijNuv1qGUouY-I1NuXZHK29041QJzyw8LFS1E67CM2_cSZN2q2Y"
  }
  ```
  """
  @type t :: %__MODULE__{
          :alg => binary(),
          :d => binary(),
          :dp => binary(),
          :dq => binary(),
          :e => binary(),
          :ext => boolean(),
          :key_ops => [binary()],
          :kty => binary(),
          :n => binary(),
          :p => binary(),
          :q => binary(),
          :qi => binary(),
          :type => binary()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "encryption_keys" do
    field(:alg, :binary)
    field(:d, ChatApi.Encrypted.Binary)
    field(:dp, ChatApi.Encrypted.Binary)
    field(:dq, ChatApi.Encrypted.Binary)
    field(:e, ChatApi.Encrypted.Binary)
    field(:ext, :boolean)
    field(:key_ops, {:array, :binary})
    field(:kty, :binary)
    field(:n, ChatApi.Encrypted.Binary)
    field(:p, ChatApi.Encrypted.Binary)
    field(:q, ChatApi.Encrypted.Binary)
    field(:qi, ChatApi.Encrypted.Binary)
    field(:type, :binary)

    belongs_to(:user, User)
    belongs_to(:conversation, Conversation)

    timestamps()
  end

  @doc false
  def changeset(encryption_key, conversation, user, attrs \\ %{}) do
    encryption_key
    |> cast(attrs, [:alg, :d, :dp, :dq, :e, :ext, :key_ops, :kty, :n, :p, :q, :qi, :type])
    |> validate_required([:alg, :e, :ext, :key_ops, :kty, :n, :type])
    |> put_assoc(:user, user)
    |> put_assoc(:conversation, conversation)
    |> unique_constraint([:user_id, :conversation_id, :type])
  end

  def get_key_by_user_conversation_type_query(user_id, conversation_id, type) do
    from(
      k in EncryptionKey,
      where: k.user_id == ^user_id and k.conversation_id == ^conversation_id and k.type == ^type
    )
  end

  def get_private_encryption_key_for_conversation(conversation_id, user_id) do
    from(
      k in EncryptionKey,
      where:
        k.user_id == ^user_id and k.conversation_id == ^conversation_id and k.type == ^"private"
    )
  end

  def get_public_encryption_key_for_conversation(conversation_id, user_id) do
    from(
      k in EncryptionKey,
      where:
        k.user_id != ^user_id and k.conversation_id == ^conversation_id and k.type == ^"public"
    )
  end
end
