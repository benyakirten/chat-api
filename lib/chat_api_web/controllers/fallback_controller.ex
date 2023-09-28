defmodule ChatApiWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use ChatApiWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: ChatApiWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :not_authorized}) do
    conn
    |> put_status(401)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:"401")
  end

  def call(conn, {:error, :missing}) do
    conn
    |> put_status(401)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:"400")
  end

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(401)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:error, reason: :invalid_credentials)
  end

  def call(conn, error) do
    IO.inspect(error)
    conn
    |> put_status(418)
    |> render(:error, error: "UH OH")
  end
end
