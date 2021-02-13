defmodule PlugSessionDbStore.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add(:session_cookie, :text, null: false)
      add(:data, :binary, null: false)
      add(:valid_from, :utc_datetime_usec)
      add(:valid_to, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists(index(:sessions, [:session_cookie]))
  end
end
