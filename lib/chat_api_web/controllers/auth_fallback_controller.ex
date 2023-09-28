defmodule ChatApiWeb.AuthFallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use ChatApiWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(401)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:error, error: :invalid_credentials)
  end
end
