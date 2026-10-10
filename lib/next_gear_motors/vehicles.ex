defmodule NextGearMotors.Vehicles do
  @moduledoc """
  The Vehicles context.
  """

  import Ecto.Query, warn: false
  alias NextGearMotors.Repo

  alias NextGearMotors.Vehicles.Vehicle
  alias NextGearMotors.Vehicles.Covers.Cover

  @doc """
  Returns the list of vehicles.

  ## Examples

      iex> list_vehicles()
      [%Vehicle{}, ...]

  """
  def list_vehicles do
    Repo.all(Vehicle)
  end

  @doc """
  Gets a single vehicle.

  Raises `Ecto.NoResultsError` if the Vehicle does not exist.

  ## Examples

      iex> get_vehicle!(123)
      %Vehicle{}

      iex> get_vehicle!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vehicle!(id), do: Repo.get!(Vehicle, id)

  @doc """
  Gets a single vehicle.

  Returns nil if the Vehicle does not exist.

  ## Examples

      iex> get_vehicle(123)
      %Vehicle{}

      iex> get_vehicle(456)
      nil

  """
  def get_vehicle(id), do: Repo.get(Vehicle, id)

  @doc """
  Creates a vehicle.

  ## Examples

      iex> create_vehicle(%{field: value})
      {:ok, %Vehicle{}}

      iex> create_vehicle(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vehicle(attrs \\ %{}) do
    %Vehicle{}
    |> Vehicle.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Accesses covers if it exists on attrs

  ## Examples

      iex> get_covers_from_attrs(%{"covers" => [...]})
      [...]

      iex> get_covers_from_attrs(%{:covers => [...]})
      [...]

      iex> get_covers_from_attrs(%{})
      nil

  """
  def get_covers_from_attrs(%{"covers" => covers}), do: covers
  def get_covers_from_attrs(%{:covers => covers}), do: covers
  def get_covers_from_attrs(_attrs), do: nil

  @doc """
  Updates a vehicle.

  ## Examples

      iex> update_vehicle(vehicle, %{field: new_value})
      {:ok, %Vehicle{}}

      iex> update_vehicle(vehicle, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_vehicle(%Vehicle{} = vehicle, attrs) do
    require Logger
    covers = get_covers_from_attrs(attrs)

    if covers && !Enum.empty?(covers) && covers != vehicle.covers do
      for cover <- vehicle.covers do
        try do
          Cover.delete({cover, vehicle})
        rescue
          e -> Logger.warning("cover delete failed reason=#{inspect(e)}")
        end
      end
    end

    vehicle
    |> Vehicle.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a vehicle.

  ## Examples

      iex> delete_vehicle(vehicle)
      {:ok, %Vehicle{}}

      iex> delete_vehicle(vehicle)
      {:error, %Ecto.Changeset{}}

  """
  def delete_vehicle(%Vehicle{} = vehicle) do
    for cover <- vehicle.covers do
      Cover.delete({cover, vehicle})
    end

    Repo.delete(vehicle)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vehicle changes.

  ## Examples

      iex> change_vehicle(vehicle)
      %Ecto.Changeset{data: %Vehicle{}}

  """
  def change_vehicle(%Vehicle{} = vehicle, attrs \\ %{}) do
    Vehicle.changeset(vehicle, attrs)
  end
end
