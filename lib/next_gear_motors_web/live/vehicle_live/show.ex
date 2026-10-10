defmodule NextGearMotorsWeb.VehicleLive.Show do
  use NextGearMotorsWeb, :live_view

  alias NextGearMotors.Vehicles
  alias NextGearMotors.Vehicles.Covers.Cover

  import NextGearMotorsWeb.Components.Carousel

  on_mount {NextGearMotorsWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, id)}
  end

  defp apply_action(socket, :edit, id) do
    current_user = socket.assigns.current_user

    if current_user && current_user.is_admin do
      socket
      |> assign(:page_title, page_title(:edit))
      |> assign(:vehicle, Vehicles.get_vehicle!(id))
    else
      socket
      |> put_flash(:error, "You must be an admin to access this resource.")
      |> push_patch(to: ~p"/vehicles/#{id}")
    end
  end

  defp apply_action(socket, :show, id) do
    socket
    |> assign(:page_title, page_title(:show))
    |> assign(:vehicle, Vehicles.get_vehicle!(id))
  end

  @impl true
  def handle_info({:put_flash, [type, message]}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp page_title(:show), do: "Show Vehicle"
  defp page_title(:edit), do: "Edit Vehicle"
end
