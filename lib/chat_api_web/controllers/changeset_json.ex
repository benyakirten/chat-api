defmodule ChatApiWeb.ChangesetJSON do
  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  def error(%{reason: :expired}), do: %{errors: %{message: "Access Token Expired"}}
  def error(%{reason: :invalid}), do: %{errors: %{message: "Access Token Invalid"}}
  def error(%{reason: :missing}), do: %{errors: %{message: "Access Token Missing"}}
  def error(%{reason: :invalid_credentials}), do: %{errors: %{message: "Invalid Email and/or Password"}}
  def error(%{reason: :invalid_token}), do: %{errors: %{message: "Invalid Token"}}
  def error(%{reason: :invalid_inputs}), do: %{errors: %{message: "Invalid Input"}}

  defp translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(ChatApiWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(ChatApiWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
