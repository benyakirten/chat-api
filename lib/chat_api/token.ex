defmodule ChatApi.Token do
  @moduledoc """
  A module with helpers for generating various tokens.
  """
  alias ChatApi.Repo
  alias ChatApi.Account.{User, UserToken}

  @seconds_in_minute 60
  @seconds_in_hour @seconds_in_minute * 60
  @seconds_in_day @seconds_in_hour * 24

  # Lifespans in seconds

  # JWT - 30 minutes
  # Refresh token - 14 days
  # Password reset - 1 day
  # Email confirmation - 7 days
  # Email change - 7 days
  @jwt_lifespan @seconds_in_minute * 30
  @refresh_token_lifespan @seconds_in_day * 14
  @password_reset_token_lifespan @seconds_in_day * 1
  @email_confirm_token_lifespan @seconds_in_day * 7
  @email_change_token_lifespan @seconds_in_day * 7

  @doc """
  Generate a token for a user given a context to decide its lifespan.
  If the user does not exist.
  """
  @spec generate_token(Ecto.UUID.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def generate_token(user_id, context) do
    if Repo.get_by(User, id: user_id) do
      lifespan = get_lifespan_from_context(context)

      token =
        Phoenix.Token.sign(
          ChatApiWeb.Endpoint,
          inspect(__MODULE__),
          user_id,
          max_age: lifespan
        )

      {:ok, token}
    else
      {:error, :not_found}
    end
  end

  defp get_lifespan_from_context("jwt"), do: @jwt_lifespan
  defp get_lifespan_from_context("refresh"), do: @refresh_token_lifespan
  defp get_lifespan_from_context("password_reset"), do: @password_reset_token_lifespan
  defp get_lifespan_from_context("email_confirm"), do: @email_confirm_token_lifespan
  defp get_lifespan_from_context("email_change"), do: @email_change_token_lifespan

  @doc """
  Check if a token has been revoked and attempt to get the user from it if it's still valid.
  """
  @spec get_user_from_token(String.t()) ::
          {:error, :revoked} | {:error, :expired | :invalid | :missing} | {:ok, String.t()}
  def get_user_from_token(token) do
    if Repo.get_by(UserToken, token: token) do
      Phoenix.Token.verify(
        ChatApiWeb.Endpoint,
        inspect(__MODULE__),
        token
      )
    else
      {:error, :revoked}
    end
  end
end
