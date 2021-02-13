defmodule PlugSessionDbStore.Sessions do
  @moduledoc """
  The Sessions context.
  """

  alias PlugSessionDbStore.Repo
  alias PlugSessionDbStore.Sessions.Session

  @doc """
  Gets a single session by cookie.

  ## Examples

      iex> get_by_session_cookie("8TLiDud0S08cPejVZlH...")
      %Session{}

      iex> get_by_session_cookie("8TLiDud0S08cPejVZlH...")
      nil

  """
  @spec get_by_session_cookie(cookie :: binary()) :: Session.t() | nil
  def get_by_session_cookie(cookie) do
    Repo.get_by(Session, session_cookie: cookie)
  end

  @doc """
  Creates a session.

  ## Examples

      iex> create_session!(%{field: value})
      %Session{}

      iex> create_session!(%{field: bad_value})
      ** (Ecto.InvalidChangesetError)

  """
  @spec create_session!(attrs :: map()) :: Session.t()
  def create_session!(attrs) do
    %Session{}
    |> Session.cng_create(attrs)
    |> Repo.insert!()
  end

  @doc """
  Updates a session.

  ## Examples

      iex> update_session!(session, %{field: new_value})
      %Session{}

      iex> update_session!(session, %{field: bad_value})
      ** (Ecto.InvalidChangesetError)

  """
  @spec update_session!(session :: Session.t(), attrs :: map()) :: Session.t()
  def update_session!(session, attrs) do
    session
    |> Session.cng_update(attrs)
    |> Repo.update!()
  end

  @doc """
  Deletes a session if one is found by the given cookie.

  ## Examples

      iex> delete_by_session_cookie("8TLiDud0S08cPejVZlH...")
      %Session{}

      iex> delete_by_session_cookie("8TLiDud0S08cPejVZlH...")
      nil

  """
  @spec delete_by_session_cookie(cookie :: binary()) :: Session.t() | nil
  def delete_by_session_cookie(cookie) do
    case get_by_session_cookie(cookie) do
      nil -> nil
      session -> Repo.delete!(session)
    end
  end
end
