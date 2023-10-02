defmodule ChatApi.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ChatApi.Chat` context.
  """

  @doc """
  Generate a conversation.
  """
  def conversation_fixture(attrs \\ %{}) do
    {:ok, conversation} =
      attrs
      |> Enum.into(%{
        alias: "some alias",
        private: true
      })
      |> ChatApi.Chat.create_conversation()

    conversation
  end

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{
        content: "some content"
      })
      |> ChatApi.Chat.create_message()

    message
  end
end
