defmodule PlugSessionDbStore.Sessions.Session do
  @moduledoc """
  Database-backed session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "sessions" do
    field(:session_cookie, :string)
    field(:data, :binary)
    field(:valid_from, :utc_datetime_usec)
    field(:valid_to, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def cng_create(session, attrs) do
    session
    |> cast(attrs, [:session_cookie, :data, :valid_from, :valid_to])
    |> validate_required([:session_cookie, :data, :valid_to])
  end

  @doc false
  def cng_update(session, attrs) do
    session
    |> cast(attrs, [:data, :valid_to])
    |> validate_required([:valid_to])
  end
end
