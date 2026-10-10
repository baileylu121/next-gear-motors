defmodule NextGearMotorsWeb.PageControllerTest do
  use NextGearMotorsWeb.ConnCase

  test "GET / has correct contents", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Your next car is already here."
  end

  test "GET / fires telemetry events", %{conn: conn} do
    ref = :telemetry_test.attach_event_handlers(self(), [[:next_gear_motors]])

    _ = get(conn, ~p"/")

    assert_received {[:next_gear_motors], ^ref, %{visits: _}, _}
  end

  test "GET / does not have a `Dashboard` header without admin login", %{conn: conn} do
    conn = get(conn, ~p"/")

    refute html_response(conn, 200) =~ "Dashboard"
  end

  test "GET /contact", %{conn: conn} do
    conn = get(conn, ~p"/contact")
    assert html_response(conn, 200) =~ "Contact Information"
  end

  test "GET /about", %{conn: conn} do
    conn = get(conn, ~p"/about")
    assert html_response(conn, 200) =~ "About Us"
  end

  test "GET /privacy", %{conn: conn} do
    conn = get(conn, ~p"/privacy")
    assert html_response(conn, 200) =~ "PRIVACY POLICY"
  end

  test "GET /cookies", %{conn: conn} do
    conn = get(conn, ~p"/cookies")
    assert html_response(conn, 200) =~ "COOKIE POLICY"
  end

  test "GET not found route", %{conn: conn} do
    conn = get(conn, ~p"/not_found")
    assert html_response(conn, 200) =~ "Page Not Found"

    conn = get(conn, ~p"/not_found1")
    assert html_response(conn, 200) =~ "Page Not Found"
  end

  describe "Admin Only" do
    setup [:register_log_in_and_promote_user]

    test "GET /", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Dashboard"
    end
  end
end
