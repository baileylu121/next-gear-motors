defmodule NextGearMotorsWeb.PageController do
  use NextGearMotorsWeb, :controller

  def home(conn, _params) do
    :telemetry.execute([:next_gear_motors], %{visits: 1})

    render(conn, :home,
      layout: false,
      featured_vehicles:
        NextGearMotors.Vehicles.list_vehicles()
        |> elem(0)
        |> Enum.filter(&(Map.get(&1, :covers, []) != []))
        |> Enum.take(3)
    )
  end

  def contact(conn, _params), do: render(conn, :contact)
  def about(conn, _params), do: render(conn, :about)
  def privacy(conn, _params), do: render(conn, :privacy)
  def cookies(conn, _params), do: render(conn, :cookies)
  def not_found(conn, _params), do: render(conn, :not_found)
end
