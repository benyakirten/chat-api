defmodule ChatApiWeb.ProfileJSON do
  @doc """
  Renders changes to the user's profile. Separate from the auth controller
  because they require a token and the pipeline is
  """

  def update_password(%{user_id: user_id}) do
    %{user_id: user_id}
  end
end
