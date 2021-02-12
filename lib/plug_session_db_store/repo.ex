defmodule PlugSessionDbStore.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :plug_session_db_store,
    adapter: Ecto.Adapters.Postgres
end
