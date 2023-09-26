defmodule ChatApi.Token do
  @moduledoc """
  A module with helpers for generating various tokens.
  """
  alias ChatApi.Account.UserToken

  @type token_type :: :auth | :refresh_token | :password_reset | :email_confirm | :email_change

  @seconds_in_minute 60
  @seconds_in_hour @seconds_in_minute * 60
  @seconds_in_day @seconds_in_hour * 24

  # Lifespans in seconds

  # JWT - 30 minutes
  # Refresh token - 14 days
  # Password reset - 1 day
  # Email confirmation - 7 days
  # Email change - 7 days
  @auth_lifespan @seconds_in_minute * 30
  @refresh_token_lifespan @seconds_in_day * 14
  @password_reset_token_lifespan @seconds_in_day * 1
  @email_confirm_token_lifespan @seconds_in_day * 7
  @email_change_token_lifespan @seconds_in_day * 7

  @doc """
  Generate a token for a user given a context to decide its lifespan.
  If the user does not exist.
  """
  @spec generate_token(Ecto.UUID.t(), atom()) :: {:ok, String.t()} | {:error, :not_found}
  def generate_token(user_id, context) do
    lifespan = token_lifespan_for_context(context)

    Phoenix.Token.sign(
      ChatApiWeb.Endpoint,
      inspect(__MODULE__),
      [id: user_id, context: context],
      max_age: lifespan
    )
  end

  @spec token_lifespan_for_context(token_type) :: number()
  def token_lifespan_for_context(:auth), do: @auth_lifespan
  def token_lifespan_for_context(:refresh), do: @refresh_token_lifespan
  def token_lifespan_for_context(:password_reset), do: @password_reset_token_lifespan
  def token_lifespan_for_context(:email_confirm), do: @email_confirm_token_lifespan
  def token_lifespan_for_context(:email_change), do: @email_change_token_lifespan

  @doc """
  Check a token for validity and if it is, get the user ID from it.
  """
  @spec get_user_from_token(String.t(), atom) ::
          {:error, :expired | :invalid | :missing | :revoked} | {:ok, String.t()}
  def get_user_from_token(token, required_context) do
    token_resolution =
      Phoenix.Token.verify(
        ChatApiWeb.Endpoint,
        inspect(__MODULE__),
        token
      )

    case token_resolution do
      {:ok, [id: user_id, context: :auth]} ->
        {:ok, user_id}

      {:ok, [id: user_id, context: context]} ->
        required_context == context and UserToken.check_token_by_context(user_id, context)

      error ->
        error
    end
  end
end
