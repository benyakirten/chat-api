defmodule ChatApiWeb.ProfileJSON do
  @doc """
  Renders changes to the user's profile. Separate from the auth controller
  because they require a token and the pipeline is
  """
  alias ChatApi.Serializer

  def update_profile(%{profile: profile}) do
    Serializer.serialize(profile)
  end

  def update_display_name(%{user: user}) do
    Serializer.serialize(user)
  end
end
