defmodule ChatApi.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query

  alias ChatApi.Repo

  alias ChatApi.Chat.{Conversation, Message}
  alias ChatApi.Account.User
  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def new_conversation(user_ids, message_content, message_sender, private \\ false, conversation_alias \\ nil) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:create_conversation, Conversation.changeset(%Conversation{private: private, alias: conversation_alias}))
    # Repo.preload gives errors in IEX - This is a temporary measure to preload the users
    # While debugging the query
    |> Ecto.Multi.run(:get_conversation, fn _repo, %{create_conversation: conversation} ->
      convo = Repo.one(from(c in Conversation, where: c.id == ^conversation.id, preload: :users))
      case convo do
        nil -> {:error, :missing_conversation}
        convo -> {:ok, convo}
      end
    end)
    |> return_error_on_no_results(:get_sender, User.user_by_id_query(message_sender), :user_not_found)
    |> Ecto.Multi.run(:add_message, fn _repo, %{get_conversation: conversation, get_sender: user} ->
      %Message{}
      |> Message.changeset(%{content: message_content})
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Ecto.Changeset.put_assoc(:conversation, conversation)
      |> Repo.insert()
    end)
    |> Ecto.Multi.all(:get_users, from(u in User, where: u.id in ^user_ids, select: u))
    |> Ecto.Multi.run(:apply_users, fn _repo, %{get_users: users, get_conversation: conversation} ->
      if length(users) == length(user_ids) do
        conversation
        |> Conversation.changeset()
        |> Ecto.Changeset.put_assoc(:users, users)
        |> Repo.update()
      else
        {:error, :invalid_ids}
      end
    end)
  end

  def update_message(message_id, user_id, content) do
    Ecto.Multi.new()
    |> Ecto.Multi.one(:get_message, Message.message_by_sender_query(message_id, user_id))
    |> Ecto.Multi.run(:update_message, fn _repo, %{get_message: message} ->
      message
      |> Message.changeset(%{content: content})
      |> Repo.update()
    end)
  end

  def delete_message(message_id, user_id) do
    Repo.delete_all(Message.message_by_sender_query(message_id, user_id))
  end

  def send_message(conversation_id, user_id, content) do
    send_conversation_message(conversation_id, user_id, content)
    |> Repo.transaction()
  end

  defp send_conversation_message(conversation_id, user_id, content) do
    # Verify that the conversation exists and has the user
    Ecto.Multi.new()
    |> return_error_on_no_results(
      :get_conversation,
      Conversation.member_of_conversation_query(conversation_id, user_id),
      :conversation_not_found
    )
    |> return_error_on_no_results(:get_user, User.user_by_id_query(user_id), :user_not_found)
    |> Ecto.Multi.run(:add_message, fn _repo, %{get_user: user, get_conversation: conversation} ->
      %Message{}
      |> Message.changeset(%{content: content})
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Ecto.Changeset.put_assoc(:conversation, conversation)
      |> Repo.insert()
    end)
  end

  # Ecto.Multi.one does not return {:ok, val} or {:error, :reason}, just nil or the value
  # This is a function just to make sure a failure stops the multi chain
  defp return_error_on_no_results(multi, operation_name, query, error_atom) do
    Ecto.Multi.run(multi, operation_name, fn _repo, _changes ->
      case Repo.one(query) do
        nil -> {:error, error_atom}
        val -> {:ok, val}
      end
    end)
  end

  def start_conversation(user_ids, private, first_message_content, first_message_sender, conversation_alias \\ nil) do
    user_ids = if first_message_sender not in user_ids, do: Enum.concat(user_ids, [first_message_sender]), else: user_ids
    if private,
      do: start_private_chat(user_ids, first_message_content, first_message_sender),
      else: start_group_chat(user_ids, first_message_content, first_message_sender, conversation_alias)
  end

  defp start_private_chat(user_ids, first_message_content, first_message_sender) do
    if length(user_ids) != 2 do
      {:error, :incorrect_num_users}
    else
      [user_id1, user_id2] = user_ids
      case Conversation.find_private_conversation_by_users_query(user_id1, user_id2) do
        {:error, :invalid_user_ids} -> {:error, :invalid_user_ids}
        query ->
          case Repo.transaction(query) do
            {:error, _atoms, error, _changes} -> {:error, error}
            {:ok, %{get_conversation: nil}} -> start_new_private_chat(user_ids, first_message_content, first_message_sender)
            {:ok, %{get_conversation: conversation}} -> use_preexisting_private_conversation(conversation.id, first_message_sender, first_message_content)
          end
      end
    end
  end

  defp use_preexisting_private_conversation(conversation_id, message_sender, message_content) do
    send_conversation_message(conversation_id, message_sender, message_content)
    |> Repo.transaction()
    |> get_conversation_users_from_multi_results()
  end

  defp start_new_private_chat(user_ids, first_message_content, first_message_sender) do
    new_conversation(user_ids, first_message_content, first_message_sender, true)
    |> Repo.transaction()
    |> get_conversation_users_from_multi_results()
  end

  defp start_group_chat(user_ids, first_message_content, first_message_sender, conversation_alias) do
    new_conversation(user_ids, first_message_content, first_message_sender, false, conversation_alias)
    |> Repo.transaction()
    |> get_conversation_users_from_multi_results()
  end

  defp get_conversation_users_from_multi_results(multi_results) do
    case multi_results do
      {:error, _error_atom, error, _changes} -> {:error, error}
      {:ok, queries} ->
        conversation = queries[:get_conversation]
        {:ok, conversation}
      error -> error
    end
  end

  def leave_conversation(conversation_id, user_id) do
    transaction = Ecto.Multi.new()
    |> Ecto.Multi.run(:get_conversation, fn _repo, _changes ->
      case Repo.one(Conversation.get_user_group_conversation_query(conversation_id, user_id)) do
        nil -> {:error, :no_conversation}
        conversation -> {:ok, conversation}
      end
    end)
    |> Ecto.Multi.run(:remove_conversation, fn _repo, %{get_conversation: conversation} ->
      query = if length(conversation.users) > 1 do
        Conversation.get_users_conversations_query(conversation.id, user_id)
      else
        Conversation.get_conversation(conversation.id)
      end

      case Repo.delete_all(query) do
        {0, _} -> {:error, :no_conversation}
        _ -> {:ok, :success}
      end
    end)

    case Repo.transaction(transaction) do
      {:error, _error_atom, error, _changesets} -> {:error, error}
      {:ok, _} -> :ok
    end
  end
end
