defmodule NextGearMotorsWeb.VehicleLiveTest do
  use NextGearMotorsWeb.ConnCase

  import Phoenix.LiveViewTest
  import NextGearMotors.VehiclesFixtures

  @create_attrs %{
    name: "some name",
    description: "some description",
    price: "€40,000",
    manufacturer: "some manufacturer"
  }
  @update_attrs %{
    name: "some updated name",
    description: "some updated description",
    price: "€50,000",
    manufacturer: "some updated manufacturer"
  }
  @invalid_attrs %{name: nil, description: nil, price: nil, manufacturer: nil}

  @cover %{
    name: "car.jpg",
    content: File.read!("test/support/fixtures/vehicles_fixtures/car.jpg"),
    type: "image/jpeg"
  }
  @updated_cover %{
    name: "updated_car.jpg",
    content: File.read!("test/support/fixtures/vehicles_fixtures/updated_car.jpg"),
    type: "image/jpeg"
  }

  defp create_vehicle(_) do
    vehicle = vehicle_fixture()
    %{vehicle: vehicle}
  end

  describe "Logged Out Index" do
    setup [:create_vehicle]

    test "lists all vehicles", %{conn: conn, vehicle: vehicle} do
      {:ok, _index_live, html} = live(conn, ~p"/vehicles")

      assert html =~ "Vehicles"
      assert html =~ vehicle.name
    end

    test "fires telemetry event", %{conn: conn} do
      ref = :telemetry_test.attach_event_handlers(self(), [[:next_gear_motors, :vehicles]])

      {:ok, _index_live, _html} = live(conn, ~p"/vehicles")

      assert_received {[:next_gear_motors, :vehicles], ^ref, %{visits: _}, _}
    end

    test "has no new button", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      refute has_element?(index_live, "a", "New Vehicle")
    end

    test "cannot open the new vehicle modal through live navigation", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      render_patch(index_live, ~p"/vehicles/new")

      assert_patch(index_live, ~p"/vehicles")

      refute has_element?(index_live, "#vehicle-form")
      assert render(index_live) =~ "You must be an admin to access this resource."
    end

    test "has no edit button", %{conn: conn, vehicle: vehicle} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      refute has_element?(index_live, "#vehicles-#{vehicle.id}-edit a")
    end

    test "has no delete button", %{conn: conn, vehicle: vehicle} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      refute has_element?(index_live, "#vehicles-#{vehicle.id}-delete a")
    end

    test "search query param filters the grid", %{conn: conn, vehicle: vehicle} do
      vehicle_fixture(%{
        name: "Honda Civic",
        manufacturer: "Honda",
        description: "zippy hatchback",
        price: "€20,000"
      })

      {:ok, _index_live, html} = live(conn, ~p"/vehicles?q=civic")

      assert html =~ "Honda Civic"
      refute html =~ vehicle.name
    end

    test "manufacturer param filters and shows count", %{conn: conn, vehicle: vehicle} do
      vehicle_fixture(%{
        name: "Honda Civic",
        manufacturer: "Honda",
        description: "zippy hatchback",
        price: "€20,000"
      })

      {:ok, index_live, _html} = live(conn, ~p"/vehicles?manufacturer=Honda")

      assert render(index_live) =~ "Honda Civic"
      refute render(index_live) =~ vehicle.name
      assert render(index_live) =~ "1 vehicle"
    end

    test "filter form change patches the URL", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      index_live
      |> form("#vehicle-filters", %{q: "civic"})
      |> render_change()

      assert_patch(index_live, ~p"/vehicles?q=civic")
    end

    test "clear filters link appears while filtering", %{conn: conn} do
      {:ok, filtering_live, _html} = live(conn, ~p"/vehicles?q=civic")

      assert has_element?(filtering_live, "a", "Clear filters")

      {:ok, clean_live, _html} = live(conn, ~p"/vehicles")

      refute has_element?(clean_live, "a", "Clear filters")
    end
  end

  describe "Logged in Index" do
    setup [:create_vehicle, :register_and_log_in_user]

    test "has no edit button", %{conn: conn, vehicle: vehicle} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      refute has_element?(index_live, "#vehicles-#{vehicle.id}-edit a")
    end

    test "has no delete button", %{conn: conn, vehicle: vehicle} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      refute has_element?(index_live, "#vehicles-#{vehicle.id}-delete a")
    end
  end

  describe "Admin Logged in Index" do
    setup [:create_vehicle, :register_log_in_and_promote_user]

    test "saves new vehicle", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      assert index_live
             |> element("a", "New Vehicle")
             |> render_click() =~ "New Vehicle"

      assert index_live
             |> form("#vehicle-form", vehicle: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> file_input("#upload-form", :covers, [@cover])
             |> render_upload("car.jpg") =~ "img src=\"/uploads/vehicles/covers"

      assert index_live
             |> form("#vehicle-form", vehicle: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/vehicles")

      html = render(index_live)
      assert html =~ "Vehicle created successfully"
      assert html =~ "some name"
    end

    test "updates vehicle in listing", %{conn: conn, vehicle: vehicle} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      assert index_live
             |> element("a#vehicles-#{vehicle.id}-edit")
             |> render_click() =~ "Edit Vehicle"

      assert_patch(index_live, ~p"/vehicles/#{vehicle}/edit")

      assert index_live
             |> form("#vehicle-form", vehicle: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#vehicle-form", vehicle: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/vehicles")

      html = render(index_live)
      assert html =~ "Vehicle updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes vehicle in listing", %{conn: conn, vehicle: vehicle} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      assert index_live |> element("a#vehicles-#{vehicle.id}-delete") |> render_click()
      refute has_element?(index_live, "#vehicles-#{vehicle.id}")
    end
  end

  describe "Logged in Show" do
    setup [:create_vehicle, :register_and_log_in_user]

    test "has no edit button", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      refute has_element?(index_live, "a", "Edit")
    end

    test "cannot open the edit modal through live navigation", %{conn: conn, vehicle: vehicle} do
      {:ok, show_live, _html} = live(conn, ~p"/vehicles/#{vehicle}")

      render_patch(show_live, ~p"/vehicles/#{vehicle}/show/edit")

      assert_patch(show_live, ~p"/vehicles/#{vehicle}")

      html = render(show_live)

      refute html =~ "Edit Vehicle"
      refute has_element?(show_live, "#vehicle-form")
      assert html =~ "You must be an admin to access this resource."
    end
  end

  describe "Admin Logged in Show" do
    setup [:create_vehicle, :register_log_in_and_promote_user]

    test "updates vehicle within modal", %{conn: conn, vehicle: vehicle} do
      {:ok, show_live, _html} = live(conn, ~p"/vehicles/#{vehicle}")

      assert show_live
             |> element("a", "Edit")
             |> render_click() =~ "Edit Vehicle"

      assert_patch(show_live, ~p"/vehicles/#{vehicle}/show/edit")

      assert show_live
             |> form("#vehicle-form", vehicle: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> file_input("#upload-form", :covers, [@updated_cover])
             |> render_upload("updated_car.jpg") =~ "img id=\"phx-preview-"

      assert show_live
             |> form("#vehicle-form", vehicle: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/vehicles/#{vehicle}")

      html = render(show_live)
      assert html =~ "Vehicle updated successfully"
      assert html =~ "some updated name"
    end
  end

  describe "Logged out Show" do
    setup [:create_vehicle]

    test "displays vehicle", %{conn: conn, vehicle: vehicle} do
      {:ok, _show_live, html} = live(conn, ~p"/vehicles/#{vehicle}")

      assert html =~ "Show Vehicle"
      assert html =~ vehicle.name
    end
  end
end
