defmodule PlugSessionDbStoreWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PlugSessionDbStoreWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PlugSessionDbStoreWeb.ConnCase

      alias PlugSessionDbStoreWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint PlugSessionDbStoreWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(PlugSessionDbStore.Repo)

    unless tags[:async] do
      Sandbox.mode(PlugSessionDbStore.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
