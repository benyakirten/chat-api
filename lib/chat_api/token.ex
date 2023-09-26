defmodule ChatApi.Token do
  @moduledoc """
  A module with helpers for auth tokens using Phoenix.Token. These are short
  lived and not encrypted
  """
  alias ChatApi.Account.User

  # Auth tokens are valid for 30 minutes * 60 seconds = 1800 seconds
  @auth_lifespan 1_800

  @doc """
  Generate an encrypted token for a user given a context to decide its lifespan.
  """
  @spec generate_auth_token(User.t()) :: String.t()
  def generate_auth_token(%User{id: user_id}) do
    Phoenix.Token.sign(
      ChatApiWeb.Endpoint,
      inspect(__MODULE__),
      user_id,
      max_age: @auth_lifespan
    )
  end

  @doc """
  Check a token for validity and if it is, get the user ID from it.
  """
  @spec user_from_auth_token(String.t()) ::
          {:error, :expired | :invalid | :missing} | {:ok, String.t()}
  def user_from_auth_token(token) do
    token_resolution =
      Phoenix.Token.verify(
        ChatApiWeb.Endpoint,
        inspect(__MODULE__),
        token
      )

    case token_resolution do
      {:ok, user_id} -> {:ok, user_id}
      error -> error
    end
  end
end
