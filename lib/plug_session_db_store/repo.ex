defmodule PlugSessionDbStore.Repo do
  use Ecto.Repo,
    otp_app: :plug_session_db_store,
    adapter: Ecto.Adapters.Postgres
end
