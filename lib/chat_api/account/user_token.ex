defmodule ChatApi.Account.UserToken do
  @moduledoc """
  A module with helpers for generating various tokens.
  """

  # Lifespans in days
  # @refresh_token_lifespan 14
  # @password_reset_token_lifespan 1
  # @email_confirm_token_lifespan 7
  # @email_change_token_lifespan 7

  def generate_token(_user) do
    1
  end

  def get_user_from_token(_token) do
    1
  end
end
