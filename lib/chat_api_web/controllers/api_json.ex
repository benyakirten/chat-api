defmodule ChatApiWeb.ApiJSON do
  alias ChatApi.Serializer

  def paginate_messages(%{messages: messages, page_size: page_size}),
    do: %{"messages" => Serializer.serialize_all(messages, page_size)}
end
