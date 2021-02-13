defmodule PlugSessionDbStoreWeb.PageView do
  @moduledoc false

  use PlugSessionDbStoreWeb, :view

  @doc false
  def timestamp(nil), do: ""

  def timestamp(datetime) do
    Timex.format!(datetime, "%d.%m.%Y %H:%M", :strftime)
  end
end
