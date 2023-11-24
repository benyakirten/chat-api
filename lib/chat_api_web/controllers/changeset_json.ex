defmodule ChatApiWeb.ChangesetJSON do
  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  # TODO: find a better place for these
  def error(%{reason: :expired}), do: format_error("Access token expired")
  def error(%{reason: :invalid}), do: format_error("Access token invalid")
  def error(%{reason: :missing}), do: format_error("Access token missing")
  def error(%{reason: :invalid_credentials}), do: format_error("Invalid email and/or password")
  def error(%{reason: :invalid_token}), do: format_error("Invalid token")
  def error(%{reason: :invalid_inputs}), do: format_error("Invalid input")

  def error(%{reason: :display_name_unchanged}),
    do: format_error("Display name must be different than previous value")

  @spec format_error(String.t()) :: map()
  defp format_error(err), do: %{error: %{message: err}}

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

  def missing_parameters(%{missing_parameters: params}) do
    %{error: %{missing_parameters: params}}
  end
end
