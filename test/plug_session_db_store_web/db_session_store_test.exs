defmodule PlugSessionDbStoreWeb.DbSessionStoreTest do
  use PlugSessionDbStoreWeb.ConnCase, async: true
  use Plug.Test

  alias PlugSessionDbStore.Repo
  alias PlugSessionDbStore.Sessions.Session
  alias PlugSessionDbStoreWeb.DbSessionStore, as: DbStore

  @default_opts [
    store: DbStore,
    key: "foobar",
    encryption_salt: "encryption salt",
    signing_salt: "signing salt",
    log: false
  ]

  @secret String.duplicate("abcdef0123456789", 8)
  @signing_opts Plug.Session.init(Keyword.put(@default_opts, :encrypt, false))
  @encrypted_opts Plug.Session.init(@default_opts)
  @prederived_opts Plug.Session.init([secret_key_base: @secret] ++ @default_opts)

  defmodule CustomSerializer do
    def encode(%{"foo" => "bar"}), do: {:ok, "encoded session"}
    def encode(%{"foo" => "baz"}), do: {:ok, "another encoded session"}
    def encode(%{}), do: {:ok, ""}
    def encode(_), do: :error

    def decode("encoded session"), do: {:ok, %{"foo" => "bar"}}
    def decode("another encoded session"), do: {:ok, %{"foo" => "baz"}}
    def decode(nil), do: {:ok, nil}
    def decode(_), do: :error
  end

  opts = Keyword.put(@default_opts, :serializer, CustomSerializer)
  @custom_serializer_opts Plug.Session.init(opts)

  @conn %{secret_key_base: @secret}
  @opts @encrypted_opts.store_config

  describe "init/1" do
    test "requires signing_salt option to be defined" do
      assert_raise ArgumentError, ~r/expects :signing_salt as option/, fn ->
        Plug.Session.init(Keyword.delete(@default_opts, :signing_salt))
      end
    end

    test "requires the secret to be at least 64 bytes" do
      assert_raise ArgumentError, ~r/to be at least 64 bytes/, fn ->
        build_conn(:get, "/")
        |> sign_conn("abcdef")
        |> put_session("foo", "bar")
        |> send_resp(200, "OK")
      end
    end

    test "default key generator opts" do
      key_generator_opts = DbStore.init(@default_opts).key_opts
      assert key_generator_opts[:iterations] == 1000
      assert key_generator_opts[:length] == 32
      assert key_generator_opts[:digest] == :sha256
    end

    test "prederives keys if secret_key_base is available" do
      assert %{encryption_salt: {:prederived, _}, signing_salt: {:prederived, _}} =
               DbStore.init([secret_key_base: @secret] ++ @default_opts)
    end

    test "uses specified key generator opts" do
      opts =
        @default_opts
        |> Keyword.put(:key_iterations, 2000)
        |> Keyword.put(:key_length, 64)
        |> Keyword.put(:key_digest, :sha)

      key_generator_opts = DbStore.init(opts).key_opts
      assert key_generator_opts[:iterations] == 2000
      assert key_generator_opts[:length] == 64
      assert key_generator_opts[:digest] == :sha
    end

    test "requires serializer option to be an atom" do
      assert_raise ArgumentError, ~r/expects :serializer option to be a module/, fn ->
        Plug.Session.init(Keyword.put(@default_opts, :serializer, "CustomSerializer"))
      end
    end

    test "uses :external_term_format cookie serializer by default" do
      assert Plug.Session.init(@default_opts).store_config.serializer == :external_term_format
    end

    test "uses custom cookie serializer" do
      assert @custom_serializer_opts.store_config.serializer == CustomSerializer
    end

    test "uses MFAs for salts" do
      opts = [
        store: DbStore,
        key: "foobar",
        encryption_salt: {__MODULE__, :returns_arg, ["encryption salt"]},
        signing_salt: {__MODULE__, :returns_arg, ["signing salt"]}
      ]

      plug = Plug.Session.init(opts)
      assert apply_mfa(plug.store_config.encryption_salt) == "encryption salt"
      assert apply_mfa(plug.store_config.signing_salt) == "signing salt"
    end

    test "when :max_age is not specified, uses a default value" do
      assert Plug.Session.init(@default_opts).store_config.max_age == 3600
    end

    test "uses specified :max_age" do
      opts = [store_max_age: 7200] ++ @default_opts
      assert Plug.Session.init(opts).store_config.max_age == 7200
    end
  end

  test "put and get session" do
    refute Repo.get_by(Session, session_cookie: "foo")

    assert "foo" = DbStore.put(@conn, "foo", %{foo: :bar}, @opts)
    assert "bar" = DbStore.put(@conn, "bar", %{bar: :foo}, @opts)

    assert Repo.get_by(Session, session_cookie: "foo")

    assert {"foo", %{foo: :bar}} = DbStore.get(@conn, "foo", @opts)
    assert {"bar", %{bar: :foo}} = DbStore.get(@conn, "bar", @opts)

    assert {nil, %{}} = DbStore.get(@conn, "unknown", @opts)
  end

  test "ignores expired sessions" do
    opts = %{@opts | max_age: 1800}

    assert "foo" = DbStore.put(@conn, "foo", %{foo: :bar}, opts)
    assert Repo.get_by(Session, session_cookie: "foo")
    assert {"foo", %{foo: :bar}} = DbStore.get(@conn, "foo", opts)

    assert "foo" = DbStore.put(@conn, "foo", %{bar: :foo}, opts)
    assert {"foo", %{bar: :foo}} = DbStore.get(@conn, "foo", opts)

    opts = %{@opts | max_age: -10}

    assert "bar" = DbStore.put(@conn, "bar", %{bar: :foo}, opts)
    assert Repo.get_by(Session, session_cookie: "bar")
    assert {nil, %{}} = DbStore.get(@conn, "bar", opts)

    assert nil == DbStore.put(@conn, "bar", %{foo: :bar}, opts)
    assert {nil, %{}} = DbStore.get(@conn, "bar", opts)
  end

  test "updates session expiry on reads and writes" do
    DbStore.put(@conn, "foo", %{foo: :bar}, @opts)
    assert session = Repo.get_by(Session, session_cookie: "foo")
    assert expiry_1 = session.valid_to

    DbStore.get(@conn, "foo", @opts)
    assert session = Repo.get_by(Session, session_cookie: "foo")
    assert expiry_2 = session.valid_to
    assert DateTime.compare(expiry_1, expiry_2) == :lt

    DbStore.put(@conn, "foo", %{bar: :foo}, @opts)
    assert session = Repo.get_by(Session, session_cookie: "foo")
    assert DateTime.compare(expiry_2, session.valid_to) == :lt
  end

  test "delete session" do
    DbStore.put(@conn, "foo", %{foo: :bar}, @opts)
    DbStore.put(@conn, "bar", %{bar: :foo}, @opts)
    assert Repo.get_by(Session, session_cookie: "foo")

    DbStore.delete(@conn, "foo", @opts)

    assert {nil, %{}} = DbStore.get(@conn, "foo", @opts)
    assert {"bar", %{bar: :foo}} = DbStore.get(@conn, "bar", @opts)
    refute Repo.get_by(Session, session_cookie: "foo")
  end

  test "generate new sid" do
    sid = DbStore.put(@conn, nil, %{}, @opts)
    assert byte_size(sid) == 128
  end

  test "invalidate sid if unknown" do
    assert {nil, %{}} = DbStore.get(@conn, "unknown_sid", @opts)
  end

  describe "signed" do
    test "session data is signed" do
      opts = @signing_opts.store_config

      cookie = DbStore.put(@conn, nil, %{"foo" => "baz"}, opts)
      assert is_binary(cookie)

      assert DbStore.get(@conn, cookie, opts) ==
               {cookie, %{"foo" => "baz"}}

      assert DbStore.get(@conn, "bad", opts) == {nil, %{}}
    end

    test "gets and sets signed session data" do
      conn =
        build_conn(:get, "/")
        |> sign_conn()
        |> put_session("foo", "bar")
        |> send_resp(200, "")

      assert build_conn(:get, "/")
             |> recycle_cookies(conn)
             |> sign_conn()
             |> get_session("foo") == "bar"
    end

    test "deletes session cookie" do
      conn =
        build_conn(:get, "/")
        |> sign_conn()
        |> put_session("foo", "bar")
        |> configure_session(drop: true)
        |> send_resp(200, "")

      assert build_conn(:get, "/")
             |> recycle_cookies(conn)
             |> sign_conn()
             |> get_session("foo") == nil
    end
  end

  describe "encrypted" do
    test "session data is encrypted" do
      opts = @encrypted_opts.store_config
      cookie = DbStore.put(@conn, nil, %{"foo" => "baz"}, opts)
      assert is_binary(cookie)

      assert DbStore.get(@conn, cookie, opts) ==
               {cookie, %{"foo" => "baz"}}

      assert DbStore.get(@conn, "bad", opts) == {nil, %{}}
    end

    test "gets and sets encrypted session data" do
      conn =
        build_conn(:get, "/")
        |> encrypt_conn()
        |> put_session("foo", "bar")
        |> send_resp(200, "")

      assert build_conn(:get, "/")
             |> recycle_cookies(conn)
             |> encrypt_conn()
             |> get_session("foo") == "bar"
    end

    test "deletes session cookie" do
      conn =
        build_conn(:get, "/")
        |> encrypt_conn()
        |> put_session("foo", "bar")
        |> configure_session(drop: true)
        |> send_resp(200, "")

      assert build_conn(:get, "/")
             |> recycle_cookies(conn)
             |> encrypt_conn()
             |> get_session("foo") == nil
    end
  end

  describe "custom serializer" do
    test "session data is serialized by the custom serializer" do
      opts = @custom_serializer_opts.store_config
      cookie = DbStore.put(@conn, nil, %{"foo" => "baz"}, opts)
      assert is_binary(cookie)

      assert DbStore.get(@conn, cookie, opts) ==
               {cookie, %{"foo" => "baz"}}
    end

    test "gets and sets custom serialized session data" do
      conn =
        build_conn(:get, "/")
        |> custom_serialize_conn()
        |> put_session("foo", "bar")
        |> send_resp(200, "")

      assert build_conn(:get, "/")
             |> recycle_cookies(conn)
             |> custom_serialize_conn()
             |> get_session("foo") == "bar"
    end

    test "deletes session cookie" do
      conn =
        build_conn(:get, "/")
        |> custom_serialize_conn()
        |> put_session("foo", "bar")
        |> configure_session(drop: true)
        |> send_resp(200, "")

      assert build_conn(:get, "/")
             |> recycle_cookies(conn)
             |> custom_serialize_conn()
             |> get_session("foo") == nil
    end
  end

  describe "prederivation" do
    test "gets and sets prederived session data" do
      conn =
        build_conn(:get, "/")
        |> prederived_conn()
        |> put_session("foo", "bar")
        |> send_resp(200, "")

      assert build_conn(:get, "/")
             |> recycle_cookies(conn)
             |> prederived_conn()
             |> get_session("foo") == "bar"
    end
  end

  def returns_arg(arg), do: arg

  defp sign_conn(conn, secret \\ @secret) do
    put_in(conn.secret_key_base, secret)
    |> Plug.Session.call(@signing_opts)
    |> fetch_session
  end

  defp encrypt_conn(conn) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(@encrypted_opts)
    |> fetch_session
  end

  defp prederived_conn(conn) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(@prederived_opts)
    |> fetch_session
  end

  defp custom_serialize_conn(conn) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(@custom_serializer_opts)
    |> fetch_session
  end

  defp apply_mfa({module, function, args}), do: apply(module, function, args)
end
