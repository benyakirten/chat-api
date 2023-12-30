defmodule ChatApi.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: ChatApi.Vault
end
