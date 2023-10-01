defmodule ChatApiWeb.ProfileJSON do
  @doc """
  Renders changes to the user's profile. Separate from the auth controller
  because they require a token and the pipeline is
  """
  alias ChatApiWeb.AuthJSON
  alias ChatApi.Account.UserProfile

  def update_profile(%{profile: profile}) do
    serialize_profile(profile)
  end

  def update_display_name(%{user: user}) do
    AuthJSON.serialize_user(user)
  end

  defp serialize_profile(%UserProfile{} = profile) do
    %{
      hidden: profile.hidden,
      theme: profile.theme,
      magnification: profile.magnification
    }
  end
end
