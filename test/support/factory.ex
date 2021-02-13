defmodule PlugSessionDbStore.Factory do
  @moduledoc false

  use EctoStreamFactory, repo: PlugSessionDbStore.Repo

  alias PlugSessionDbStore.Sessions.Session

  def session_generator do
    gen all(
          session_cookie <- string(:ascii, length: 128),
          data <- constant(<<131, 116, 0, 0, 0, 0>>),
          validity_sec <- positive_integer()
        ) do
      %Session{
        session_cookie: session_cookie,
        data: data,
        valid_from: DateTime.utc_now(),
        valid_to: DateTime.add(DateTime.utc_now(), validity_sec, :second)
      }
    end
  end
end
