defmodule ChatApi.Parameters do
  @doc """
  Given a map of parameters, return a list of all that are missing from the parameters.
  """
  @spec list_missing_params(map(), [binary()]) :: :ok | {:missing_parameters, [binary()]}
  def list_missing_params(params, required_params) do
    items =
      Enum.reduce(required_params, [], fn next, acc ->
        case Map.get(params, next) do
          item when not is_nil(item) -> acc
          _ -> Enum.concat(acc, [next])
        end
      end)

    if length(items) > 0 do
      {:missing_parameters, items}
    else
      :ok
    end
  end
end
