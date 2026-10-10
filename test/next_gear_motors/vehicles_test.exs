defmodule NextGearMotors.VehiclesTest do
  use NextGearMotors.DataCase

  alias NextGearMotors.Vehicles
  alias NextGearMotors.Vehicles.Covers.Cover

  setup do
    File.mkdir_p("priv/static/test/uploads")
    File.mkdir_p("priv/static/test/tmp")
    System.put_env("TMPDIR", "priv/static/tmp")

    on_exit(fn ->
      File.rm_rf("priv/static/test/uploads")
      File.rm_rf("priv/static/test/tmp")
    end)
  end

  describe "vehicles" do
    alias NextGearMotors.Vehicles.Vehicle

    import NextGearMotors.VehiclesFixtures

    @invalid_attrs %{name: nil, description: nil, price: nil, manufacturer: nil, covers: nil}

    test "list_vehicles/0 returns all vehicles" do
      vehicle = vehicle_fixture()
      assert {vehicles, %Flop.Meta{}} = Vehicles.list_vehicles()
      assert vehicles == [vehicle]
    end

    test "search finds a vehicle by name case-insensitively" do
      civic =
        vehicle_fixture(%{
          name: "Honda Civic",
          manufacturer: "Honda",
          description: "zippy hatchback"
        })

      _other =
        vehicle_fixture(%{name: "Ford Focus", manufacturer: "Ford", description: "family car"})

      assert {vehicles, %Flop.Meta{}} = Vehicles.list_vehicles(%{q: "civic"})
      assert Enum.map(vehicles, & &1.id) == [civic.id]
    end

    test "search finds a vehicle by manufacturer" do
      civic =
        vehicle_fixture(%{
          name: "Honda Civic",
          manufacturer: "Honda",
          description: "zippy hatchback"
        })

      _other =
        vehicle_fixture(%{name: "Ford Focus", manufacturer: "Ford", description: "family car"})

      assert {vehicles, %Flop.Meta{}} = Vehicles.list_vehicles(%{"q" => "honda"})
      assert Enum.map(vehicles, & &1.id) == [civic.id]
    end

    test "search finds a vehicle by description keyword" do
      civic =
        vehicle_fixture(%{
          name: "Honda Civic",
          manufacturer: "Honda",
          description: "zippy hatchback"
        })

      _other =
        vehicle_fixture(%{name: "Ford Focus", manufacturer: "Ford", description: "family car"})

      assert {vehicles, %Flop.Meta{}} = Vehicles.list_vehicles(%{"q" => "zippy"})
      assert Enum.map(vehicles, & &1.id) == [civic.id]
    end

    test "blank manufacturer returns all vehicles" do
      a = vehicle_fixture(%{name: "Honda Civic", manufacturer: "Honda"})
      b = vehicle_fixture(%{name: "Ford Focus", manufacturer: "Ford"})
      assert {vehicles, _} = Vehicles.list_vehicles(%{manufacturer: ""})
      assert Enum.map(vehicles, & &1.id) |> Enum.sort() == Enum.sort([a.id, b.id])
    end

    test "exact manufacturer returns only that make" do
      civic = vehicle_fixture(%{name: "Honda Civic", manufacturer: "Honda"})
      _other = vehicle_fixture(%{name: "Ford Focus", manufacturer: "Ford"})
      assert {vehicles, _} = Vehicles.list_vehicles(%{"manufacturer" => "Honda"})
      assert Enum.map(vehicles, & &1.id) == [civic.id]
    end

    test "sort name_az orders names A to Z" do
      vehicle_fixture(%{name: "Honda Civic", manufacturer: "Honda"})
      vehicle_fixture(%{name: "Audi A4", manufacturer: "Audi"})
      assert {vehicles, _} = Vehicles.list_vehicles(%{"sort" => "name_az"})
      assert Enum.map(vehicles, & &1.name) == ["Audi A4", "Honda Civic"]
    end

    test "sort name_za orders names Z to A" do
      vehicle_fixture(%{name: "Honda Civic", manufacturer: "Honda"})
      vehicle_fixture(%{name: "Audi A4", manufacturer: "Audi"})
      assert {vehicles, _} = Vehicles.list_vehicles(%{"sort" => "name_za"})
      assert Enum.map(vehicles, & &1.name) == ["Honda Civic", "Audi A4"]
    end

    test "sort make_az orders manufacturers A to Z" do
      vehicle_fixture(%{name: "Honda Civic", manufacturer: "Honda"})
      vehicle_fixture(%{name: "Audi A4", manufacturer: "Audi"})
      assert {vehicles, _} = Vehicles.list_vehicles(%{"sort" => "make_az"})
      assert Enum.map(vehicles, & &1.manufacturer) == ["Audi", "Honda"]
    end

    test "sort newest falls back to default order" do
      vehicle_fixture(%{name: "Honda Civic", manufacturer: "Honda"})
      vehicle_fixture(%{name: "Audi A4", manufacturer: "Audi"})
      assert {newest, _} = Vehicles.list_vehicles(%{"sort" => "newest"})
      assert {default, _} = Vehicles.list_vehicles()
      assert Enum.map(newest, & &1.id) == Enum.map(default, & &1.id)
    end

    test "hostile input falls back to defaults without error" do
      a = vehicle_fixture(%{name: "Honda Civic", manufacturer: "Honda"})
      b = vehicle_fixture(%{name: "Ford Focus", manufacturer: "Ford"})
      assert {vehicles, %Flop.Meta{}} = Vehicles.list_vehicles(%{sort: "drop table", q: ""})
      assert Enum.map(vehicles, & &1.id) |> Enum.sort() == Enum.sort([a.id, b.id])
    end

    test "unknown filter keys are ignored" do
      vehicle = vehicle_fixture()

      assert {vehicles, %Flop.Meta{}} =
               Vehicles.list_vehicles(%{
                 "filters" => [%{"field" => "nope", "op" => :==, "value" => "x"}]
               })

      assert vehicles == [vehicle]
    end

    test "list_manufacturers/0 returns distinct makes sorted A-Z" do
      vehicle_fixture(%{name: "Honda Civic", manufacturer: "Honda"})
      vehicle_fixture(%{name: "Ford Focus", manufacturer: "Ford"})
      vehicle_fixture(%{name: "Honda Accord", manufacturer: "Honda"})
      assert Vehicles.list_manufacturers() == ["Ford", "Honda"]
    end

    test "get_vehicle!/1 returns the vehicle with given id" do
      vehicle = vehicle_fixture()
      assert Vehicles.get_vehicle!(vehicle.id) == vehicle
    end

    test "create_vehicle/1 with valid data creates a vehicle" do
      cover_a = %Plug.Upload{
        path: "test/support/fixtures/vehicles_fixtures/car.jpg",
        filename: "car.jpg",
        content_type: "image/jpeg"
      }

      cover_b = %Plug.Upload{
        path: "test/support/fixtures/vehicles_fixtures/updated_car.jpg",
        filename: "updated_car.jpg",
        content_type: "image/jpeg"
      }

      valid_attrs = %{
        name: "some name",
        description: "some description",
        price: "€40,000.50",
        manufacturer: "some manufacturer",
        covers: [cover_a, cover_b]
      }

      assert {:ok, %Vehicle{} = vehicle} = Vehicles.create_vehicle(valid_attrs)
      assert vehicle.name == "some name"
      assert vehicle.description == "some description"
      assert vehicle.price == "€40,000.50"
      assert vehicle.manufacturer == "some manufacturer"

      [vehicle_cover_a, vehicle_cover_b] = vehicle.covers
      assert vehicle_cover_a.file_name == "car.jpg"
      assert vehicle_cover_b.file_name == "updated_car.jpg"
    end

    test "create_vehicle/1 with invalid price returns error changeset" do
      cover = %Plug.Upload{
        path: "test/support/fixtures/vehicles_fixtures/car.jpg",
        filename: "car.jpg",
        content_type: "image/jpeg"
      }

      invalid_attrs = %{
        name: "some name",
        description: "some description",
        price: "invalid price",
        manufacturer: "some manufacturer",
        cover: [cover],
        covers_uploads_status: :unfinished
      }

      assert {:error, %Ecto.Changeset{}} = Vehicles.create_vehicle(invalid_attrs)
    end

    test "create_vehicle/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Vehicles.create_vehicle(@invalid_attrs)
    end

    test "update_vehicle/2 with empty covers does not update covers" do
      vehicle = vehicle_fixture()
      [prev_cover] = vehicle.covers

      update_attrs = %{
        name: "some updated name",
        description: "some updated description",
        price: "€50,000",
        manufacturer: "some updated manufacturer"
      }

      assert {:ok, %Vehicle{} = vehicle} = Vehicles.update_vehicle(vehicle, update_attrs)
      assert vehicle.covers == [prev_cover]
      assert File.exists?("priv/static" <> Cover.url(prev_cover))
    end

    test "update_vehicle/2 with valid data updates the vehicle" do
      vehicle = vehicle_fixture()
      [prev_cover] = vehicle.covers

      updated_cover = %Plug.Upload{
        path: "test/support/fixtures/vehicles_fixtures/updated_car.jpg",
        filename: "updated_car.jpg",
        content_type: "image/jpeg"
      }

      update_attrs = %{
        name: "some updated name",
        description: "some updated description",
        price: "€50,000",
        manufacturer: "some updated manufacturer",
        covers: [updated_cover]
      }

      assert {:ok, %Vehicle{} = vehicle} = Vehicles.update_vehicle(vehicle, update_attrs)
      assert vehicle.name == "some updated name"
      assert vehicle.description == "some updated description"
      assert vehicle.price == "€50,000"
      assert vehicle.manufacturer == "some updated manufacturer"

      [vehicle_cover] = vehicle.covers
      assert vehicle_cover.file_name == "updated_car.jpg"

      refute File.exists?("priv/static" <> Cover.url(prev_cover))
    end

    test "update_vehicle/2 with invalid data returns error changeset" do
      vehicle = vehicle_fixture()
      assert {:error, %Ecto.Changeset{}} = Vehicles.update_vehicle(vehicle, @invalid_attrs)
      assert vehicle == Vehicles.get_vehicle!(vehicle.id)
    end

    test "delete_vehicle/1 deletes the vehicle" do
      vehicle = vehicle_fixture()
      [prev_cover] = vehicle.covers

      assert {:ok, %Vehicle{}} = Vehicles.delete_vehicle(vehicle)
      assert_raise Ecto.NoResultsError, fn -> Vehicles.get_vehicle!(vehicle.id) end

      refute File.exists?("priv/static" <> Cover.url(prev_cover))
    end

    test "change_vehicle/1 returns a vehicle changeset" do
      vehicle = vehicle_fixture()
      assert %Ecto.Changeset{} = Vehicles.change_vehicle(vehicle)
    end
  end
end
