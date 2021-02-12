defmodule PlugSessionDbStoreWeb.PageController do
  use PlugSessionDbStoreWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
