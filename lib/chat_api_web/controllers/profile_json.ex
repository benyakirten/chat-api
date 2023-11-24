defmodule ChatApiWeb.ProfileJSON do
  @moduledoc """
  Renders changes to the user's profile. Separate from the auth controller
  because profile changes require an auth token.
  """
  alias ChatApi.Serializer

  def update_profile(%{profile: profile}) do
    Serializer.serialize(profile)
  end

  def update_display_name(%{user: user}) do
    Serializer.serialize(user)
  end
end
