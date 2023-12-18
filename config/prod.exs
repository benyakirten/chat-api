import Config

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: ChatApi.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
config :chat_api, ChatApi.Account, frontend_url: System.fetch_env!("FRONTEND_URL")

config :chat_api, ChatApi.Account.UserNotifier, from_email: System.fetch_env!("FROM_EMAIL")

config :chat_api, ChatApi.Vault,
  json_library: Jason,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: System.fetch_env!("VAULT_KEY")}
  ]
