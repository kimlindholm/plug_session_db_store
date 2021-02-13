defmodule PlugSessionDbStoreWeb.DbSessionStore do
  @moduledoc """
  Stores the session in the database.

  This module is based on code published here
  https://github.com/elixir-plug/plug/blob/2361bd3ca8f4c3ecd44c1ff33df6c184f7cbf512/lib/plug/session/cookie.ex
  as part of the Plug project, as of Feb 7 2021. It is used in
  accordance with the project's license:

  > Copyright (c) 2013 Plataformatec.
  >
  >   Licensed under the Apache License, Version 2.0 (the "License");
  >   you may not use this file except in compliance with the License.
  >   You may obtain a copy of the License at
  >
  >       http://www.apache.org/licenses/LICENSE-2.0
  >
  >   Unless required by applicable law or agreed to in writing, software
  >   distributed under the License is distributed on an "AS IS" BASIS,
  >   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  >   See the License for the specific language governing permissions and
  >   limitations under the License.

  This store is based on `Plug.Crypto.MessageVerifier` and
  `Plug.Crypto.MessageEncryptor` which encrypts and signs session data
  to ensure they can't be read nor tampered with.

  Since this store uses crypto features, it requires you to set the
  `:secret_key_base` field in your connection. This can be easily
  achieved with a plug:

      plug :put_secret_key_base

      def put_secret_key_base(conn, _) do
        put_in conn.secret_key_base, "-- LONG STRING WITH AT LEAST 64 BYTES --"
      end

  ## Miscellaneous

  In order to clean up expired sessions, a periodic task needs to be
  created.

  ## Options

    * `:secret_key_base` - the secret key base to build the
      signing/encryption on top of. If one is given on initialization,
      the database store can precompute all relevant values at
      compilation time. Otherwise, the value is taken from
      `conn.secret_key_base` and cached.

    * `:encryption_salt` - a salt used with `conn.secret_key_base` to
      generate a key for encrypting/decrypting data, can be either a
      binary or an MFA returning a binary;

    * `:signing_salt` - a salt used with `conn.secret_key_base` to
      generate a key for signing/verifying data, can be either a binary
      or an MFA returning a binary;

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000;

    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32;

    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`;

    * `:serializer` - serializer module that defines `encode/1` and
      `decode/1` returning an `{:ok, value}` tuple. Defaults to
      `:external_term_format`.

    * `:log` - Log level to use when the data cannot be decoded.
      Defaults to `:debug`, can be set to false to disable it.

    * `:store_max_age` - Session expiry in seconds, defaults to 1 hour

  ## Examples

      max_age = 7_889_400

      plug(Plug.Session,
        store: MyAppWeb.DbSessionStore,
        key: "_my_app_key",
        encryption_salt: "encryption salt",
        signing_salt: "signing salt",
        key_length: 64,
        log: :debug,
        max_age: max_age,
        store_max_age: max_age
      )

  """

  @behaviour Plug.Session.Store

  require Logger

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageEncryptor
  alias Plug.Crypto.MessageVerifier
  alias PlugSessionDbStore.Sessions
  alias PlugSessionDbStore.Sessions.Session

  @impl true
  def init(opts \\ []) do
    encryption_salt = opts[:encryption_salt]
    signing_salt = check_signing_salt(opts)

    iterations = Keyword.get(opts, :key_iterations, 1000)
    length = Keyword.get(opts, :key_length, 32)
    digest = Keyword.get(opts, :key_digest, :sha256)
    log = Keyword.get(opts, :log, :debug)
    secret_key_base = Keyword.get(opts, :secret_key_base)
    key_opts = [iterations: iterations, length: length, digest: digest, cache: Plug.Keys]
    max_age = Keyword.get(opts, :store_max_age, 3600)

    serializer = check_serializer(opts[:serializer] || :external_term_format)

    %{
      encryption_salt: prederive(secret_key_base, encryption_salt, key_opts),
      signing_salt: prederive(secret_key_base, signing_salt, key_opts),
      key_opts: key_opts,
      serializer: serializer,
      log: log,
      max_age: max_age
    }
  end

  @impl true
  def get(_conn, cookie, _opts)
      when cookie == ""
      when is_nil(cookie) do
    {nil, %{}}
  end

  @impl true
  def get(conn, cookie, opts) do
    session = Sessions.get_by_session_cookie(cookie)
    get_for_session(conn, cookie, session, opts)
  end

  @impl true
  def put(conn, cookie, term, opts)
      when cookie == ""
      when is_nil(cookie) do
    put_new(conn, term, opts)
  end

  @impl true
  def put(conn, cookie, term, opts) do
    session = Sessions.get_by_session_cookie(cookie)
    put_for_session(conn, cookie, session, term, opts)
  end

  @impl true
  def delete(_conn, cookie, _opts)
      when cookie == ""
      when is_nil(cookie) do
    :ok
  end

  @impl true
  def delete(_conn, cookie, _opts) do
    Sessions.delete_by_session_cookie(cookie)
    :ok
  end

  defp get_for_session(_conn, _cookie, nil, _opts), do: {nil, %{}}

  defp get_for_session(
         conn,
         cookie,
         %Session{valid_to: valid_to, data: data} = session,
         %{max_age: max_age} = opts
       ) do
    if DateTime.compare(now(), valid_to) == :lt do
      {_, term} = data_to_term(conn, data, opts)
      valid_to = seconds_from(now(), max_age)

      Sessions.update_session!(session, %{valid_to: valid_to})

      {cookie, term}
    else
      {nil, %{}}
    end
  end

  defp put_new(conn, term, opts) do
    create_session!(conn, term, opts)
  end

  defp put_for_session(conn, cookie, nil, term, opts) do
    create_session!(conn, cookie, term, opts)
  end

  defp put_for_session(
         conn,
         cookie,
         %Session{valid_to: valid_to} = session,
         term,
         opts
       ) do
    if DateTime.compare(now(), valid_to) == :lt do
      data = term_to_data(conn, term, opts)
      valid_to = seconds_from(now(), opts.max_age)

      Sessions.update_session!(session, %{data: data, valid_to: valid_to})

      cookie
    else
      nil
    end
  end

  defp create_session!(conn, cookie \\ nil, term, %{max_age: max_age} = opts) do
    cookie = cookie || :crypto.strong_rand_bytes(96) |> Base.encode64()
    data = term_to_data(conn, term, opts)
    valid_from = now()
    valid_to = seconds_from(valid_from, max_age)

    Sessions.create_session!(%{
      session_cookie: cookie,
      data: data,
      valid_from: valid_from,
      valid_to: valid_to
    })

    cookie
  end

  defp data_to_term(conn, data, %{
         key_opts: key_opts,
         encryption_salt: encryption_salt,
         signing_salt: signing_salt,
         log: log,
         serializer: serializer
       }) do
    case encryption_salt do
      nil ->
        MessageVerifier.verify(
          data,
          derive(conn.secret_key_base, signing_salt, key_opts)
        )

      encryption_salt ->
        MessageEncryptor.decrypt(
          data,
          derive(conn.secret_key_base, encryption_salt, key_opts),
          derive(conn.secret_key_base, signing_salt, key_opts)
        )
    end
    |> decode(serializer, log)
  end

  defp term_to_data(conn, term, %{
         serializer: serializer,
         key_opts: key_opts,
         encryption_salt: encryption_salt,
         signing_salt: signing_salt
       }) do
    binary = encode(term, serializer)

    case encryption_salt do
      nil ->
        MessageVerifier.sign(
          binary,
          derive(conn.secret_key_base, signing_salt, key_opts)
        )

      encryption_salt ->
        MessageEncryptor.encrypt(
          binary,
          derive(conn.secret_key_base, encryption_salt, key_opts),
          derive(conn.secret_key_base, signing_salt, key_opts)
        )
    end
  end

  defp encode(term, :external_term_format) do
    :erlang.term_to_binary(term)
  end

  defp encode(term, serializer) do
    {:ok, binary} = serializer.encode(term)
    binary
  end

  defp decode({:ok, binary}, :external_term_format, log) do
    {:term,
     try do
       Plug.Crypto.non_executable_binary_to_term(binary)
     rescue
       e ->
         Logger.log(
           log,
           "Plug.Session could not decode incoming session data. Reason: " <>
             Exception.message(e)
         )

         %{}
     end}
  end

  defp decode({:ok, binary}, serializer, _log) do
    case serializer.decode(binary) do
      {:ok, term} -> {:custom, term}
      _ -> {:custom, %{}}
    end
  end

  defp decode(:error, _serializer, false) do
    {nil, %{}}
  end

  defp decode(:error, _serializer, log) do
    Logger.log(
      log,
      "Plug.Session could not verify incoming session data. " <>
        "This may happen when the session settings change or a stale cookie is sent."
    )

    {nil, %{}}
  end

  defp prederive(secret_key_base, value, key_opts)
       when is_binary(secret_key_base) and is_binary(value) do
    {:prederived, derive(secret_key_base, value, Keyword.delete(key_opts, :cache))}
  end

  defp prederive(_secret_key_base, value, _key_opts) do
    value
  end

  defp derive(_secret_key_base, {:prederived, value}, _key_opts) do
    value
  end

  defp derive(secret_key_base, {module, function, args}, key_opts) do
    derive(secret_key_base, apply(module, function, args), key_opts)
  end

  defp derive(secret_key_base, key, key_opts) do
    secret_key_base
    |> validate_secret_key_base()
    |> KeyGenerator.generate(key, key_opts)
  end

  defp validate_secret_key_base(nil),
    do: raise(ArgumentError, "database store expects conn.secret_key_base to be set")

  defp validate_secret_key_base(secret_key_base) when byte_size(secret_key_base) < 64,
    do:
      raise(ArgumentError, "database store expects conn.secret_key_base to be at least 64 bytes")

  defp validate_secret_key_base(secret_key_base), do: secret_key_base

  defp check_signing_salt(opts) do
    case opts[:signing_salt] do
      nil -> raise ArgumentError, "database store expects :signing_salt as option"
      salt -> salt
    end
  end

  defp check_serializer(serializer) when is_atom(serializer), do: serializer

  defp check_serializer(_),
    do: raise(ArgumentError, "database store expects :serializer option to be a module")

  defp now do
    DateTime.utc_now()
  end

  defp seconds_from(datetime, seconds) do
    DateTime.add(datetime, seconds, :second)
  end
end
