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

  @doc """
  Create a new conversation with the given user ids.
  Options include:
  > `:private` - boolean, required
  > `:alias` - string, optional, defaults to `nil` (only for group conversations)
  """
  @spec new_conversation([binary()], map()) :: Ecto.Multi.t()
  def new_conversation(
        multi \\ Ecto.Multi.new(),
        user_ids,
        opts
      ) do
    private = opts[:private]
    conversation_alias = Map.get(opts, :alias, nil)

    # Change private and conversation to map with private Map.get
    multi
    |> Ecto.Multi.all(:get_users, from(u in User, where: u.id in ^user_ids, select: u))
    |> Ecto.Multi.run(
      :create_conversation,
      fn _repo, %{get_users: users} ->
        Conversation.changeset(%Conversation{private: private, alias: conversation_alias})
        |> Ecto.Changeset.put_assoc(:users, users)
        |> Repo.insert()
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
        first_user_id,
        user_ids,
        public_key,
        private_key
      ) do
    if length(user_ids) != 2 do
      {:error, :incorrect_num_users}
    else
      [user_id1, user_id2] = user_ids

      Ecto.Multi.new()
      |> Ecto.Multi.run(:no_previous_conversation, fn _repo, _changes ->
        query = Conversation.find_private_conversation_by_users_query(user_id1, user_id2)

        case Repo.one(query) do
          nil -> {:ok, :no_previous_conversation}
          _ -> {:error, :conversation_already_exists}
        end
      end)
      |> new_conversation(
        user_ids,
        %{private: true}
      )
      |> Ecto.Multi.run(
        :add_keys,
        fn _repo, %{create_conversation: conversation, get_users: users} ->
          user = Enum.find(users, &(&1.id == first_user_id))

          public_key_changeset =
            %EncryptionKey{}
            |> EncryptionKey.changeset(conversation, user, Map.put(public_key, "type", "public"))

          private_key_changeset =
            %EncryptionKey{}
            |> EncryptionKey.changeset(
              conversation,
              user,
              Map.put(private_key, "type", "private")
            )

          with {:ok, public_key} <- Repo.insert(public_key_changeset),
               {:ok, private_key} <- Repo.insert(private_key_changeset) do
            {:ok, {public_key, private_key}}
          else
            error ->
              IO.inspect("HERE")
              IO.inspect(error)
              error
          end
        end
      )
      |> Repo.transaction()
      |> get_conversation_users_from_multi_results()
    end
  end

  def start_group_conversation(
        user_ids,
        conversation_alias \\ nil
      ) do
    new_conversation(
      user_ids,
      %{private: false, alias: conversation_alias}
    )
    |> Repo.transaction()
    |> get_conversation_users_from_multi_results()
  end

  defp get_conversation_users_from_multi_results(multi_results) do
    case multi_results do
      {:error, _error_atom, error, _changes} ->
        {:error, error}

      {:ok, queries} ->
        conversation = queries[:create_conversation]
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
      |> Ecto.Multi.run(:get_keys, fn _repo, %{get_conversation: conversation} ->
        if conversation.private do
          public_key =
            EncryptionKey.public_key_query(conversation.id, user_id)
            |> Repo.one()

          private_key =
            EncryptionKey.private_key_query(conversation.id, user_id)
            |> Repo.one()

          {:ok, %{public_key: public_key, private_key: private_key}}
        else
          {:ok, %{public_key: nil, private_key: nil}}
        end
      end)
      |> Repo.transaction()

    case transaction do
      {:error, _change_atom, error, _changes} ->
        {:error, error}

      {:ok, results} ->
        %{
          get_conversation: conversation,
          get_read_times: read_times,
          get_keys: %{public_key: public_key, private_key: private_key}
        } = results

        {:ok,
         %{
           conversation: conversation,
           read_times: read_times,
           public_key: public_key,
           private_key: private_key
         }}
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

  @spec private_conversation(binary(), binary()) :: nil | Conversation.t()
  def private_conversation(user_id1, user_id2) do
    Conversation.find_private_conversation_by_users_query(user_id1, user_id2) |> Repo.one()
  end

  @spec set_user_encryption_keys(Conversation.t(), User.t(), map(), map()) ::
          {:error, :failed_to_insert_keys} | {:ok, {EncryptionKey.t(), EncryptionKey.t()}}
  def set_user_encryption_keys(conversation, user, public_key, private_key) do
    pub_key =
      %EncryptionKey{}
      |> EncryptionKey.changeset(conversation, user, Map.put(public_key, "type", "public"))

    priv_key =
      %EncryptionKey{}
      |> EncryptionKey.changeset(conversation, user, Map.put(private_key, "type", "private"))

    with {:ok, inserted_pub_key} <- Repo.insert(pub_key),
         {:ok, inserted_priv_key} <- Repo.insert(priv_key) do
      {:ok, {inserted_pub_key, inserted_priv_key}}
    else
      error ->
        {:error, error}
    end
  end
end
