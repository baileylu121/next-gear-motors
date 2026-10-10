defmodule NextGearMotorsWeb.ReservationLive.Index do
  use NextGearMotorsWeb, :live_view

  alias NextGearMotors.Reservations
  alias NextGearMotors.Vehicles
  alias NextGearMotors.Reservations.Reservation
  alias NextGearMotors.Accounts

  import NextGearMotorsWeb.VehicleHelper

  on_mount {NextGearMotorsWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> load_reservations()

    {:ok, socket}
  end

  defp load_reservations(socket) do
    if socket.assigns.current_user.is_admin do
      socket
      |> stream(:reservations, Reservations.list_reservations())
    else
      with_reservations =
        socket.assigns.current_user
        |> Accounts.preload_reservations()

      socket
      |> assign(:current_user, with_reservations)
      |> stream(:reservations, with_reservations.reservations)
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def row_with_user_and_vehicle({id, reservation}) do
    reservation =
      reservation
      |> Reservations.preload([:vehicle, :user])

    {
      id,
      reservation
    }
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    reservation =
      Reservations.get_reservation!(id)
      |> Reservations.preload(:vehicle)

    socket
    |> assign(:page_title, "Edit Reservation")
    |> assign(:reservation, reservation)
    |> assign(:vehicle, reservation.vehicle)
  end

  defp apply_action(socket, :new, %{"vehicle_id" => vehicle_id}) do
    case Vehicles.get_vehicle(vehicle_id) do
      nil ->
        socket
        |> put_flash(:error, "No vehicle exists for this id.")
        |> push_navigate(to: ~p"/vehicles")

      vehicle ->
        socket
        |> assign(:vehicle, vehicle)
        |> assign(:page_title, "New Reservation")
        |> assign(:reservation, %Reservation{})
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Reservations")
    |> assign(:reservation, nil)
  end

  @impl true
  def handle_info(
        {NextGearMotorsWeb.ReservationLive.FormComponent, {:saved, reservation}},
        socket
      ) do
    {:noreply, stream_insert(socket, :reservations, reservation)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    reservation = Reservations.get_reservation!(id)
    {:ok, _} = Reservations.delete_reservation(reservation)

    {:noreply, stream_delete(socket, :reservations, reservation)}
  end
end
