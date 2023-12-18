defmodule ChatApi.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query

  alias ChatApi.{Pagination, Serializer, Repo}
  alias ChatApi.Chat.{Conversation, Message, EncryptionKey}
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

  def new_conversation(
        user_ids,
        private \\ false,
        conversation_alias \\ nil
      ) do
    # Change private and conversation to map with private Map.get
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :create_conversation,
      Conversation.changeset(%Conversation{private: private, alias: conversation_alias})
    )
    |> Ecto.Multi.run(:get_conversation, fn _repo, %{create_conversation: conversation} ->
      convo = Repo.one(from(c in Conversation, where: c.id == ^conversation.id, preload: :users))

      case convo do
        nil -> {:error, :missing_conversation}
        convo -> {:ok, convo}
      end
    end)
    |> Ecto.Multi.all(:get_users, from(u in User, where: u.id in ^user_ids, select: u))
    |> Ecto.Multi.run(
      :apply_users,
      fn _repo, %{get_users: users, get_conversation: conversation} ->
        # Make sure all the user ids correspond to users
        if length(users) == length(user_ids) do
          conversation
          |> Conversation.changeset()
          |> Ecto.Changeset.put_assoc(:users, users)
          |> Repo.update()
        else
          {:error, :invalid_ids}
        end
      end
    )
  end

  def update_message(message_id, user_id, content) do
    transaction =
      Ecto.Multi.new()
      |> Ecto.Multi.one(:get_message, Message.message_by_sender_query(message_id, user_id))
      |> Ecto.Multi.run(:update_message, fn _repo, %{get_message: message} ->
        message
        |> Message.changeset(%{content: content})
        |> Repo.update()
      end)
      |> Repo.transaction()

    case transaction do
      {:error, _change_atom, error, _changes} ->
        {:error, error}

      {:ok, changes} ->
        {:ok, changes[:update_message]}
    end
  end

  def delete_message(message_id, user_id) do
    result = Repo.delete_all(Message.message_by_sender_query(message_id, user_id))

    case result do
      {0, _} -> :error
      _ -> :ok
    end
  end

  def send_message(conversation_id, user_id, content) do
    transaction =
      send_conversation_message(conversation_id, user_id, content)
      |> Repo.transaction()

    case transaction do
      {:error, _change_atoms, error, _changes} ->
        {:error, error}

      {:ok, changes} ->
        message = changes[:add_message]
        {:ok, message}
    end
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

  def start_private_conversation(
        user_ids,
        public_key,
        private_key
      ) do
    start_private_chat(
      user_ids,
      public_key,
      private_key
    )
  end

  def start_group_conversation(
        user_ids,
        conversation_alias \\ nil
      ) do
    start_group_chat(
      user_ids,
      conversation_alias
    )
  end

  defp start_private_chat(
         user_ids,
         public_key,
         private_key
       ) do
    if length(user_ids) != 2 do
      {:error, :incorrect_num_users}
    else
      [user_id1, user_id2] = user_ids

      case Conversation.find_private_conversation_by_users_query(user_id1, user_id2) do
        {:error, :invalid_user_ids} ->
          {:error, :invalid_user_ids}

        query ->
          case Repo.transaction(query) do
            {:error, _atoms, error, _changes} ->
              {:error, error}

            {:ok, %{get_conversation: nil}} ->
              start_new_private_chat(
                user_ids,
                public_key,
                private_key
              )

            {:ok, %{get_conversation: _conversation}} ->
              {:error, :conversation_already_exists}
          end
      end
    end
  end

  defp start_new_private_chat(
         user_ids,
         public_key,
         private_key
       ) do
    new_conversation(
      user_ids,
      true
    )
    |> Ecto.Multi.run(
      :add_keys,
      fn _repo, %{get_conversation: conversation, get_sender: user} ->
        public_key_changeset =
          %EncryptionKey{}
          |> EncryptionKey.changeset(user, conversation, Map.put(public_key, "type", "public"))

        private_key_changeset =
          %EncryptionKey{}
          |> EncryptionKey.changeset(user, conversation, Map.put(private_key, "type", "private"))

        with {:ok, public_key} <- Repo.insert(public_key_changeset),
             {:ok, private_key} <- Repo.insert(private_key_changeset) do
          {:ok, {public_key, private_key}}
        else
          error -> error
        end
      end
    )
    |> Repo.transaction()
    |> get_conversation_users_from_multi_results()
  end

  defp start_group_chat(
         user_ids,
         conversation_alias
       ) do
    new_conversation(
      user_ids,
      false,
      conversation_alias
    )
    |> Repo.transaction()
    |> get_conversation_users_from_multi_results()
  end

  defp get_conversation_users_from_multi_results(multi_results) do
    case multi_results do
      {:error, _error_atom, error, _changes} ->
        {:error, error}

      {:ok, queries} ->
        conversation = queries[:get_conversation]
        {:ok, conversation}

      error ->
        error
    end
  end

  def leave_conversation(conversation_id, user_id) do
    transaction =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:get_conversation, fn _repo, _changes ->
        case Repo.one(Conversation.user_group_conversation_query(conversation_id, user_id)) do
          nil -> {:error, :no_conversation}
          conversation -> {:ok, conversation}
        end
      end)
      |> Ecto.Multi.run(:remove_conversation, fn _repo, %{get_conversation: conversation} ->
        query =
          if length(conversation.users) > 1 do
            Conversation.users_conversations_query(conversation.id, user_id)
          else
            Conversation.conversation_by_id_query(conversation.id)
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

  @doc """
  Also verifies that the user is part of the conversation.
  """
  def get_conversation_details(conversation_id, user_id) do
    transaction =
      Ecto.Multi.new()
      |> return_error_on_no_results(
        :get_conversation,
        Conversation.user_conversation_with_details_query(conversation_id, user_id),
        :no_conversation
      )
      |> Ecto.Multi.run(:get_read_times, fn _repo, _changes ->
        raw_read_times =
          Repo.all(Conversation.read_time_for_users_in_conversation_query(conversation_id))

        read_times =
          Enum.reduce(raw_read_times, %{}, fn {binary_id, time}, acc ->
            uuid = Ecto.UUID.load!(binary_id)
            timezoned_time = Serializer.attach_javascript_timezone(time)
            Map.put(acc, uuid, timezoned_time)
          end)

        {:ok, read_times}
      end)
      |> Repo.transaction()

    case transaction do
      {:error, _change_atom, error, _changes} ->
        {:error, error}

      {:ok, results} ->
        %{get_conversation: conversation, get_read_times: read_times} = results
        {:ok, conversation, read_times}
    end
  end

  def change_conversation_alias(conversation_id, new_alias) do
    multi =
      Ecto.Multi.new()
      |> return_error_on_no_results(
        :get_conversation,
        Conversation.conversation_by_id_query(conversation_id),
        :no_conversation
      )
      |> Ecto.Multi.run(:update_conversation_alias, fn _repo, %{get_conversation: conversation} ->
        if conversation.private do
          {:error, :private_conversation}
        else
          Conversation.changeset(conversation, %{alias: new_alias})
          |> Repo.update()
        end
      end)
      |> Repo.transaction()

    case multi do
      {:error, _change_atom, error, _changes} -> {:error, error}
      {:ok, changes} -> {:ok, changes[:update_conversation_alias]}
    end
  end

  def update_read_time(conversation_id, user_id) do
    result =
      Repo.update_all(
        Conversation.users_conversations_query(conversation_id, user_id),
        set: [last_read: DateTime.utc_now()]
      )

    case result do
      {0, _} -> :error
      _ -> :ok
    end
  end

  def modify_conversation(conversation_id, new_member_ids, new_alias) do
    transaction =
      Ecto.Multi.new()
      |> return_error_on_no_results(
        :get_conversation,
        Conversation.private_conversation_query(conversation_id),
        :no_conversation
      )
      |> Ecto.Multi.run(:get_users, fn _repo, %{get_conversation: conversation} ->
        user_ids =
          Stream.map(conversation.users, & &1.id)
          |> Stream.concat(new_member_ids)
          |> Enum.to_list()

        users = Repo.all(User.multiple_users_by_id_query(user_ids))

        if length(users) == length(user_ids) do
          {:ok, users}
        else
          {:error, :users_not_found}
        end
      end)
      |> Ecto.Multi.run(
        :update_conversation,
        fn _repo,
           %{
             get_conversation: conversation,
             get_users: users
           } ->
          Conversation.changeset(conversation, %{alias: new_alias})
          |> Ecto.Changeset.put_assoc(:users, users)
          |> Repo.update()
        end
      )

    case Repo.transaction(transaction) do
      {:ok, changes} ->
        conversation = changes[:update_conversation]
        user_ids = Enum.map(conversation.users, & &1.id)
        {:ok, conversation, user_ids}

      {:error, _changes, error, _change_atoms} ->
        {:error, error}
    end
  end

  # @spec paginate_more_messages(binary(), binary(), binary(), pos_integer() | nil) ::
  def paginate_more_messages(
        conversation_id,
        user_id,
        page_token,
        page_size \\ Pagination.default_page_size()
      ) do
    query =
      Conversation.user_conversation_with_details_query(conversation_id, user_id, %{
        "page_size" => page_size,
        "page_token" => page_token
      })

    case Repo.one(query) do
      nil -> {:error, :invalid_conversation}
      conversation -> {:ok, conversation.messages, page_size}
    end
  end
end
