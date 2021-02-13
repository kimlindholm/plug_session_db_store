defmodule PlugSessionDbStoreWeb.PageControllerTest do
  use PlugSessionDbStoreWeb.ConnCase

  setup do
    conn = build_conn() |> init_test_session(%{})
    %{conn: conn}
  end

  describe "GET /" do
    test "saves current time in the session", %{conn: conn} do
      in_the_past = DateTime.utc_now() |> DateTime.add(-1800, :second)

      conn =
        conn
        |> put_session(:last_visited_at, in_the_past)
        |> get(root_path(conn, :index))

      assert last_visited_at = get_session(conn, :last_visited_at)
      assert DateTime.compare(in_the_past, last_visited_at) == :lt
    end

    test "redirects to the last visit page", %{conn: conn} do
      conn = get(conn, root_path(conn, :index))
      assert redirected_to(conn) == last_visit_path(conn, :last_visit)
    end
  end

  describe "GET /last_visit" do
    test "renders the time of the last visit", %{conn: conn} do
      last_visited_at = ~U[2021-02-07 10:15:00Z]

      conn =
        conn
        |> put_session(:last_visited_at, last_visited_at)
        |> get(last_visit_path(conn, :last_visit))

      assert res = html_response(conn, 200)
      assert res =~ "07.02.2021 10:15"
      refute res =~ "qa-main-page-link"
    end

    test "when last_visited_at is not found in the session, renders a link to the main page",
         %{conn: conn} do
      conn = get(conn, last_visit_path(conn, :last_visit))
      assert html_response(conn, 200) =~ "qa-main-page-link"
    end
  end
end
