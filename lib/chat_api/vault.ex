defmodule ChatApi.Vault do
  @moduledoc """
  This is configured to get the key from the environment variable `CLOAK_KEY`
  if the environment is production, otherwise use a hard coded value.

  Documentation for this type of setup is [here](https://hexdocs.pm/cloak/install.html)

  This looks like it's an anti-pattern according to the [Elixir docs](https://hexdocs.pm/elixir/1.16/process-anti-patterns.html#code-organization-by-process),
  but cloak has imposed it upon us.
  """
  use Cloak.Vault, otp_app: :chat_api

  @impl GenServer
  def init(config) do
    key =
      if System.get_env("CURRENT_ENV") == "production" do
        decode_env!("CLOAK_KEY")
      else
        Base.decode64!("MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTI=")
      end

    {:ok, config}

    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: key, iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    var
    |> System.get_env()
    |> Base.decode64!()
  end
end
