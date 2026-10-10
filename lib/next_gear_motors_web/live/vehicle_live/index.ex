defmodule NextGearMotorsWeb.VehicleLive.Index do
  use NextGearMotorsWeb, :live_view

  alias NextGearMotors.Vehicles
  alias NextGearMotors.Vehicles.Vehicle

  alias NextGearMotors.Vehicles.Covers.Cover

  on_mount {NextGearMotorsWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    :telemetry.execute([:next_gear_motors, :vehicles], %{visits: 1})

    socket =
      socket
      |> assign(:manufacturers, Vehicles.list_manufacturers())
      |> stream(:vehicles, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id} = params) do
    current_user = socket.assigns.current_user

    if current_user && current_user.is_admin do
      socket
      |> assign(:page_title, "Edit Vehicle")
      |> assign(:vehicle, Vehicles.get_vehicle!(id))
      |> assign_filters(params)
    else
      socket
      |> put_flash(:error, "You must be an admin to access this resource.")
      |> push_patch(to: ~p"/vehicles")
    end
  end

  defp apply_action(socket, :new, params) do
    current_user = socket.assigns.current_user

    if current_user && current_user.is_admin do
      socket
      |> assign(:page_title, "New Vehicle")
      |> assign(:vehicle, %Vehicle{})
      |> assign_filters(params)
    else
      socket
      |> put_flash(:error, "You must be an admin to access this resource.")
      |> push_patch(to: ~p"/vehicles")
    end
  end

  defp apply_action(socket, :index, params) do
    socket
    |> assign(:page_title, "Vehicles")
    |> assign(:vehicle, nil)
    |> assign_filters(params)
  end

  defp assign_filters(socket, params) do
    q = params |> Map.get("q", "") |> to_string() |> String.trim()
    manufacturer = params |> Map.get("manufacturer", "") |> to_string() |> String.trim()
    sort = parse_sort(params["sort"])
    sort_param = Atom.to_string(sort)

    {vehicles, meta} =
      Vehicles.list_vehicles(%{"q" => q, "manufacturer" => manufacturer, "sort" => sort_param})

    socket
    |> assign(:meta, meta)
    |> assign(:query, q)
    |> assign(:manufacturer, manufacturer)
    |> assign(:sort, sort)
    |> assign(:filtering, q != "" or manufacturer != "")
    |> assign(:vehicle_count, meta.total_count)
    |> assign(
      :filter_form,
      to_form(%{"q" => q, "manufacturer" => manufacturer, "sort" => sort_param})
    )
    |> stream(:vehicles, vehicles, reset: true)
  end

  defp parse_sort("name_az"), do: :name_az
  defp parse_sort("name_za"), do: :name_za
  defp parse_sort("make_az"), do: :make_az
  defp parse_sort(_), do: :newest

  @impl true
  def handle_event("filter", params, socket) do
    q = params |> Map.get("q", "") |> to_string() |> String.trim()
    manufacturer = params |> Map.get("manufacturer", "") |> to_string() |> String.trim()

    query_params =
      %{}
      |> maybe_put("q", q)
      |> maybe_put("manufacturer", manufacturer)
      |> maybe_put("sort", sort_param(params["sort"]))

    {:noreply, push_patch(socket, to: ~p"/vehicles?#{query_params}")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    if current_user && current_user.is_admin do
      vehicle = Vehicles.get_vehicle!(id)
      {:ok, _} = Vehicles.delete_vehicle(vehicle)

      {_vehicles, meta} =
        Vehicles.list_vehicles(%{
          "q" => socket.assigns.query,
          "manufacturer" => socket.assigns.manufacturer,
          "sort" => Atom.to_string(socket.assigns.sort)
        })

      socket =
        socket
        |> stream_delete(:vehicles, vehicle)
        |> assign(:meta, meta)
        |> assign(:vehicle_count, meta.total_count)
        |> assign(:manufacturers, Vehicles.list_manufacturers())

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "You must be an admin to access this resource.")}
    end
  end

  defp sort_param("name_az"), do: "name_az"
  defp sort_param("name_za"), do: "name_za"
  defp sort_param("make_az"), do: "make_az"
  defp sort_param(_), do: nil

  defp maybe_put(params, _key, ""), do: params
  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  @impl true
  def handle_info({:put_flash, [type, message]}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end

  def handle_info({NextGearMotorsWeb.VehicleLive.FormComponent, {:saved, _vehicle}}, socket) do
    {vehicles, meta} =
      Vehicles.list_vehicles(%{
        "q" => socket.assigns.query,
        "manufacturer" => socket.assigns.manufacturer,
        "sort" => Atom.to_string(socket.assigns.sort)
      })

    socket =
      socket
      |> assign(:meta, meta)
      |> assign(:vehicle_count, meta.total_count)
      |> assign(:manufacturers, Vehicles.list_manufacturers())
      |> stream(:vehicles, vehicles, reset: true)

    {:noreply, socket}
  end
end
