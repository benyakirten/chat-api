defmodule ChatApi.Account.UserNotifier do
  import Swoosh.Email

  alias ChatApi.Mailer
  alias ChatApi.Account.User

  @type limited_token_type :: :email_confirmation | :email_change | :password_reset

  @moduledoc """
  TODO: Write description
  TODO: Adapt this for my needs
  TODO: Make the templates look better
  """

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    from = Application.fetch_env!(:chat_api, ChatApi.Account.UserNotifier)[:from_email]
    email =
      new()
      |> to(recipient)
      |> from({"Chat Api", from})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok}
    end
  end

  @spec deliver_email(limited_token_type(), User.t(), String.t()) :: {:ok}
  def deliver_email(:email_confirmation, user, url), do: deliver_confirmation_instructions(user, url)
  def deliver_email(:email_change, user, url), do: deliver_update_email_instructions(user, url)
  def deliver_email(:password_reset, user, url), do: deliver_reset_password_instructions(user, url)

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.user_name},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
