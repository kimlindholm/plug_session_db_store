defmodule PlugSessionDbStore.SessionsTest do
  use PlugSessionDbStore.DataCase

  alias PlugSessionDbStore.Factory
  alias PlugSessionDbStore.Sessions
  alias PlugSessionDbStore.Sessions.Session

  describe "get_by_session_cookie/1" do
    test "returns the session with given session cookie" do
      session = Factory.insert(:session)
      assert Sessions.get_by_session_cookie(session.session_cookie) == session
    end

    test "returns nil when session is not found" do
      assert Sessions.get_by_session_cookie("non-existent") == nil
    end
  end

  describe "create_session!/1" do
    test "creates a session" do
      attrs =
        Factory.build(:session, session_cookie: "some_cookie")
        |> Map.from_struct()

      assert %Session{session_cookie: "some_cookie"} = Sessions.create_session!(attrs)
    end

    test "raises with invalid data" do
      invalid_attrs =
        Factory.build(:session, valid_to: nil)
        |> Map.from_struct()

      assert_raise Ecto.InvalidChangesetError, fn ->
        Sessions.create_session!(invalid_attrs)
      end
    end
  end

  describe "update_session!/2" do
    test "updates the session" do
      session = Factory.insert(:session)
      new_data = <<131, 100, 0, 3, 110, 105, 108>>
      assert session.data != new_data

      session = Sessions.update_session!(session, %{data: new_data})
      assert session.data == new_data
    end

    test "raises with invalid data" do
      session = Factory.insert(:session)
      invalid_attrs = %{valid_to: nil}

      assert_raise Ecto.InvalidChangesetError, fn ->
        Sessions.update_session!(session, invalid_attrs)
      end

      assert session == Repo.get(Session, session.id)
    end
  end

  describe "delete_by_session_cookie/1" do
    test "deletes the session" do
      %Session{session_cookie: cookie} = Factory.insert(:session)

      assert %Session{} = Sessions.delete_by_session_cookie(cookie)
      refute Repo.get_by(Session, session_cookie: cookie)
    end

    test "returns nil when session is not found" do
      assert Sessions.delete_by_session_cookie("non-existent") == nil
    end
  end
end
