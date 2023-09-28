defmodule ChatApiWeb.Plugs.Token do
  @moduledoc """
  A module plug for extracting and validating the user's auth token
  in the bearer format. The following outcomes can happen:
  {:ok, <user_id>} if the token is able to be parsed successfully and is still active
  {:error, :missing} if the authorization header is absent
  {:error, :invalid} if the authorization header is not in the format 'Bearer <token>'
  {:error, :invalid} if the authorization header has been tampered with
  {:error, :expired} if the token is older than the maximum age (30 minutes)

  The following errors can also occur if I messed something up but should never occur:
  {:error, :invalid} if the signing salt or the secret is not the same between signing and verifying
  {:error, :missing} if nil is passed in as the token

  TODO: Add examples
  """
  import Plug.Conn
  alias ChatApi.Token

  def init(default), do: default

  def call(conn, _opts) do
    with {:ok, token} <- get_token(conn),
     {:ok, user_id} <- Token.user_from_auth_token(token)
    do
      conn |> assign(:user_id, user_id)
    else
      {:error, reason} -> conn |> assign(:error, reason) |> halt()
    end
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      absent when absent == [] -> {:error, :missing}
      _ -> {:error, :invalid}
    end
  end
end
