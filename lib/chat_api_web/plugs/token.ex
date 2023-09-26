defmodule ChatApiWeb.Plugs.Token do
  @moduledoc """
  A module plug for extracting and validating the
  """
  import Plug.Conn
  alias ChatApi.Token

  def init(default), do: default

  def call(conn, _opts) do
    token_result = conn |> get_token() |> Token.user_from_auth_token()

    case token_result do
      {:ok, user_id} -> assign(conn, :user_id, user_id)
      # TODO: Decide when it doesn't work
      {:error, :reason} -> conn |> put_status(:unauthorized) |> halt()
    end
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      absent when absent == [] -> {:error, :no_header}
      _ -> {:error, :invalid}
    end
  end
end
