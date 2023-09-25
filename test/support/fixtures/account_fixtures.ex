defmodule ChatApi.AccountFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ChatApi.Account` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{

      })
      |> ChatApi.Account.create_user()

    user
  end
end
