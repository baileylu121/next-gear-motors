defmodule NextGearMotors.Vehicles.Vehicle do
  @moduledoc """
  # Vehicle Schema

  The type and constraints for a vehicle, the primary object sold in the store
  """

  use Ecto.Schema
  use Waffle.Ecto.Schema
  use Flop.Schema
  import Ecto.Changeset

  alias NextGearMotors.Vehicles.Covers.Cover
  alias NextGearMotors.Vehicles.Vehicle.UploadsStatusType

  @flop_options [
    filterable: [:search, :manufacturer],
    sortable: [:name, :manufacturer, :inserted_at, :id],
    default_limit: false,
    default_order: %{order_by: [:inserted_at, :id], order_directions: [:desc, :desc]},
    adapter_opts: [
      compound_fields: [search: [:name, :manufacturer, :description]]
    ]
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "vehicles" do
    field :name, :string
    field :description, :string
    field :price, :string
    field :manufacturer, :string
    field :covers, {:array, Cover.Type}, default: []
    field :covers_uploads_status, UploadsStatusType, virtual: true, default: :finished
    has_many :reservations, NextGearMotors.Reservations.Reservation

    timestamps(type: :utc_datetime)
  end

  def changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, [:name, :covers, :price, :description, :manufacturer, :covers_uploads_status])
    |> validate_required([
      :name,
      :covers,
      :price,
      :description,
      :manufacturer,
      :covers_uploads_status
    ])
    |> validate_inclusion(:covers_uploads_status, [:finished],
      message: "all image uploads must be finished"
    )
    |> validate_format(:price, ~r/^€[0-9|,|\.]*$/,
      message: "must be a number in euro - i.e. '€19,999.99'"
    )
    |> validate_length(:covers, min: 1, max: 20)
  end
end
