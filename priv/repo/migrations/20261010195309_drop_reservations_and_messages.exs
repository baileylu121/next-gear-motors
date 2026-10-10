defmodule NextGearMotors.Repo.Migrations.DropReservationsAndMessages do
  use Ecto.Migration

  def up do
    drop table(:messages)
    drop table(:reservations)
  end

  def down do
    create table(:reservations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string
      add :planned_meeting_time, :naive_datetime
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)
      add :vehicle_id, references(:vehicles, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:reservations, [:user_id])
    create index(:reservations, [:vehicle_id])

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :text, :string
      add :reservation_id, references(:reservations, on_delete: :delete_all, type: :binary_id)
      add :from_id, references(:users, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:reservation_id])
    create index(:messages, [:from_id])
  end
end
