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

  Accepts pretty `q`/`manufacturer`/`sort` params (string or atom keys),
  or native Flop `"filters"`/`"order_by"` params.

  ## Examples

      iex> {[%Vehicle{}, ...], %Flop.Meta{}} = list_vehicles()

  """
  def list_vehicles(params \\ %{}) do
    case Flop.validate_and_run(Vehicle, normalize_params(params),
           for: Vehicle,
           replace_invalid_params: true
         ) do
      {:ok, result} -> result
      {:error, _} -> Flop.validate_and_run!(Vehicle, %{}, for: Vehicle)
    end
  end

  @doc """
  Returns distinct non-empty manufacturers ordered A–Z.
  """
  def list_manufacturers do
    Vehicle
    |> where([v], not is_nil(v.manufacturer) and v.manufacturer != "")
    |> distinct(true)
    |> order_by([v], asc: v.manufacturer)
    |> select([v], v.manufacturer)
    |> Repo.all()
  end

  defp normalize_params(params) when is_map(params) do
    if Map.has_key?(params, "filters") or Map.has_key?(params, :filters) or
         Map.has_key?(params, "order_by") or Map.has_key?(params, :order_by) do
      params
    else
      q = params |> Map.get("q", Map.get(params, :q, "")) |> to_string() |> String.trim()

      manufacturer =
        params
        |> Map.get("manufacturer", Map.get(params, :manufacturer, ""))
        |> to_string()
        |> String.trim()

      sort = params |> Map.get("sort", Map.get(params, :sort, "")) |> to_string()

      filters =
        [
          q != "" && %{field: :search, op: :ilike_or, value: q},
          manufacturer != "" && %{field: :manufacturer, op: :==, value: manufacturer}
        ]
        |> Enum.filter(& &1)

      case sort_params(sort) do
        nil ->
          %{filters: filters}

        {order_by, order_directions} ->
          %{filters: filters, order_by: order_by, order_directions: order_directions}
      end
    end
  end

  defp sort_params("name_az"), do: {[:name, :id], [:asc, :asc]}
  defp sort_params("name_za"), do: {[:name, :id], [:desc, :desc]}
  defp sort_params("make_az"), do: {[:manufacturer, :name, :id], [:asc, :asc, :asc]}
  defp sort_params(_), do: nil

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
