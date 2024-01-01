defmodule ChatApi.Vault do
  @moduledoc """
  This is configured to get the key from the environment variable `VAULT_KEY`
  if the environment is production, otherwise use a hard coded value.

  Documentation for this type of setup is [here](https://hexdocs.pm/cloak/install.html)
  """
  use Cloak.Vault, otp_app: :chat_api

  @impl GenServer
  def init(config) do
    key = Application.fetch_env!(:chat_api, ChatApi.Vault)[:vault_key] |> Base.decode64!()

    ciphers = [
      default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: key}
    ]

    config =
      config
      |> Keyword.put(:json_library, Jason)
      |> Keyword.put(:ciphers, ciphers)

    {:ok, config}
  end
end
