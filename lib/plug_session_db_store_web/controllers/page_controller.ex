defmodule PlugSessionDbStoreWeb.PageController do
  @moduledoc false

  use PlugSessionDbStoreWeb, :controller

  @doc false
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
