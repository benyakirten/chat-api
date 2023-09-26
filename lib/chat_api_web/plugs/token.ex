defmodule ChatApiWeb.Plugs.Token do
  @moduledoc """
  A module plug for extracting and validating the
  """
  import Plug.Conn
  alias ChatApi.Token

  def init(default), do: default

  @spec call(Plug.Conn.t(), Token.token_type()) :: Plug.Conn.t()
  def call(conn, required_context) do
    token_result = conn |> get_token() |> Token.get_user_from_token(required_context)

    case token_result do
      {:ok, user_id} -> assign(conn, :user_id, user_id)
      # TODO: Decide when it doesn't work
      {:error, :reason} -> conn |> put_status(:unauthorized) |> halt()
    end
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      absent when absent == [] -> {:error, :not_present}
      _ -> {:error, :bad_shape}
    end
  end
end
