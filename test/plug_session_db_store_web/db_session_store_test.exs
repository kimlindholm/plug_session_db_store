defmodule PlugSessionDbStoreWeb.DbSessionStoreTest do
  use PlugSessionDbStoreWeb.ConnCase, async: true

  alias PlugSessionDbStore.Repo
  alias PlugSessionDbStore.Sessions.Session
  alias PlugSessionDbStoreWeb.DbSessionStore, as: DbStore

  describe "init/1" do
    test "when opts are not specified, uses default values" do
      opts = DbStore.init()
      assert opts[:max_age] == 3600
    end

    test "uses specified opts" do
      opts = DbStore.init(store_max_age: 7200)
      assert opts[:max_age] == 7200
    end
  end

  test "put and get session" do
    opts = DbStore.init()
    refute Repo.get_by(Session, session_cookie: "foo")

    assert "foo" = DbStore.put(%{}, "foo", %{foo: :bar}, opts)
    assert "bar" = DbStore.put(%{}, "bar", %{bar: :foo}, opts)

    assert Repo.get_by(Session, session_cookie: "foo")

    assert {"foo", %{foo: :bar}} = DbStore.get(%{}, "foo", opts)
    assert {"bar", %{bar: :foo}} = DbStore.get(%{}, "bar", opts)

    assert {nil, %{}} = DbStore.get(%{}, "unknown", opts)
  end

  test "ignores expired sessions" do
    opts = DbStore.init(store_max_age: 1800)

    assert "foo" = DbStore.put(%{}, "foo", %{foo: :bar}, opts)
    assert Repo.get_by(Session, session_cookie: "foo")
    assert {"foo", %{foo: :bar}} = DbStore.get(%{}, "foo", opts)

    assert "foo" = DbStore.put(%{}, "foo", %{bar: :foo}, opts)
    assert {"foo", %{bar: :foo}} = DbStore.get(%{}, "foo", opts)

    opts = DbStore.init(store_max_age: -10)

    assert "bar" = DbStore.put(%{}, "bar", %{bar: :foo}, opts)
    assert Repo.get_by(Session, session_cookie: "bar")
    assert {nil, %{}} = DbStore.get(%{}, "bar", opts)

    assert nil == DbStore.put(%{}, "bar", %{foo: :bar}, opts)
    assert {nil, %{}} = DbStore.get(%{}, "bar", opts)
  end

  test "updates session expiry on reads and writes" do
    opts = DbStore.init()

    DbStore.put(%{}, "foo", %{foo: :bar}, opts)
    assert session = Repo.get_by(Session, session_cookie: "foo")
    assert expiry_1 = session.valid_to

    DbStore.get(%{}, "foo", opts)
    assert session = Repo.get_by(Session, session_cookie: "foo")
    assert expiry_2 = session.valid_to
    assert DateTime.compare(expiry_1, expiry_2) == :lt

    DbStore.put(%{}, "foo", %{bar: :foo}, opts)
    assert session = Repo.get_by(Session, session_cookie: "foo")
    assert DateTime.compare(expiry_2, session.valid_to) == :lt
  end

  test "delete session" do
    opts = DbStore.init()

    DbStore.put(%{}, "foo", %{foo: :bar}, opts)
    DbStore.put(%{}, "bar", %{bar: :foo}, opts)
    assert Repo.get_by(Session, session_cookie: "foo")

    DbStore.delete(%{}, "foo", opts)

    assert {nil, %{}} = DbStore.get(%{}, "foo", opts)
    assert {"bar", %{bar: :foo}} = DbStore.get(%{}, "bar", opts)
    refute Repo.get_by(Session, session_cookie: "foo")
  end

  test "generate new sid" do
    opts = DbStore.init()
    sid = DbStore.put(%{}, nil, %{}, opts)
    assert byte_size(sid) == 128
  end

  test "invalidate sid if unknown" do
    opts = DbStore.init()
    assert {nil, %{}} = DbStore.get(%{}, "unknown_sid", opts)
  end
end
