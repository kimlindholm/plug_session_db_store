defmodule PlugSessionDbStoreWeb.PageController do
  @moduledoc false

  use PlugSessionDbStoreWeb, :controller

  @doc """
  Saves the time of the current visit in the session and redirects to
  a summary page.
  """
  @spec index(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def index(conn, _params) do
    last_visited_at = DateTime.utc_now()

    conn
    |> put_session(:last_visited_at, last_visited_at)
    |> redirect(to: Routes.last_visit_path(conn, :last_visit))
  end

  @doc """
  Shows the time of the last visit if one is found in the session.
  """
  @spec last_visit(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def last_visit(conn, _params) do
    last_visited_at = get_session(conn, :last_visited_at)
    render(conn, "last_visit.html", last_visited_at: last_visited_at)
  end
end
