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
    |> render(:"401")
  end

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(401)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:error, reason: :invalid_credentials)
  end

  def call(conn, {:error, :invalid_token}) do
    conn
    |> put_status(400)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:error, reason: :invalid_token)
  end

  def call(conn, {:missing_parameters, params}) do
    conn
    |> put_status(400)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:missing_parameters, missing_parameters: params)
  end

  def call(conn, _opts) do
    conn
    |> put_status(400)
    |> put_view(json: ChatApiWeb.ChangesetJSON)
    |> render(:error, reason: :invalid_inputs)
  end
end
