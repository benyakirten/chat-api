defmodule ChatApiWeb.ApiJSON do
  alias ChatApi.Serializer

  def paginate_items(%{items: items, page_size: page_size, key: key}) do
    Map.put(%{}, key, Serializer.serialize_all(items, page_size))
  end
end
