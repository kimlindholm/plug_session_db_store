defmodule PlugSessionDbStoreWeb.DbSessionStore do
  @moduledoc """
  Stores the session in the database.

  In order to clean up expired sessions, a periodic task needs to be
  created.

  ## Options

    * `:store_max_age` - Session expiry in seconds, defaults to 1 hour

  ## Examples

      max_age = 7_889_400

      plug(Plug.Session,
        store: MyAppWeb.DbSessionStore,
        key: "_my_app_key",
        max_age: max_age,
        store_max_age: max_age
      )

  """

  @behaviour Plug.Session.Store

  alias PlugSessionDbStore.Sessions
  alias PlugSessionDbStore.Sessions.Session

  @impl true
  def init(opts \\ []) do
    max_age = Keyword.get(opts, :store_max_age, 3600)

    %{max_age: max_age}
  end

  @impl true
  def get(_conn, cookie, _opts)
      when cookie == ""
      when is_nil(cookie) do
    {nil, %{}}
  end

  @impl true
  def get(_conn, cookie, opts) do
    session = Sessions.get_by_session_cookie(cookie)
    get_for_session(cookie, session, opts)
  end

  @impl true
  def put(_conn, cookie, term, opts)
      when cookie == ""
      when is_nil(cookie) do
    put_new(term, opts)
  end

  @impl true
  def put(_conn, cookie, term, opts) do
    session = Sessions.get_by_session_cookie(cookie)
    put_for_session(cookie, session, term, opts)
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

  defp get_for_session(_cookie, nil, _opts), do: {nil, %{}}

  defp get_for_session(
         cookie,
         %Session{valid_to: valid_to, data: data} = session,
         %{max_age: max_age}
       ) do
    if DateTime.compare(now(), valid_to) == :lt do
      term = :erlang.binary_to_term(data)
      valid_to = seconds_from(now(), max_age)

      Sessions.update_session!(session, %{valid_to: valid_to})

      {cookie, term}
    else
      {nil, %{}}
    end
  end

  defp put_new(term, opts) do
    create_session!(term, opts)
  end

  defp put_for_session(cookie, nil, term, opts) do
    create_session!(cookie, term, opts)
  end

  defp put_for_session(
         cookie,
         %Session{valid_to: valid_to} = session,
         term,
         %{max_age: max_age}
       ) do
    if DateTime.compare(now(), valid_to) == :lt do
      data = :erlang.term_to_binary(term)
      valid_to = seconds_from(now(), max_age)

      Sessions.update_session!(session, %{data: data, valid_to: valid_to})
      cookie
    else
      nil
    end
  end

  defp create_session!(cookie \\ nil, term, %{max_age: max_age}) do
    cookie = cookie || :crypto.strong_rand_bytes(96) |> Base.encode64()
    data = :erlang.term_to_binary(term)
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

  defp now do
    DateTime.utc_now()
  end

  defp seconds_from(datetime, seconds) do
    DateTime.add(datetime, seconds, :second)
  end
end
