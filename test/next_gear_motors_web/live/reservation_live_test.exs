defmodule NextGearMotorsWeb.ReservationLiveTest do
  use NextGearMotorsWeb.ConnCase
  use ExUnitProperties

  alias NextGearMotors.Reservations.Messages

  import Phoenix.LiveViewTest
  import NextGearMotors.ReservationsFixtures
  import NextGearMotors.Reservations.MessagesFixtures
  import NextGearMotors.VehiclesFixtures

  @create_attrs %{planned_meeting_time: "2025-05-19T21:58:00"}
  @update_attrs %{planned_meeting_time: "2025-05-20T21:58:00"}
  @invalid_attrs %{planned_meeting_time: nil}

  @admin_update_attrs %{planned_meeting_time: "2025-05-20T21:58:00", status: :accepted}
  @admin_invalid_attrs %{planned_meeting_time: nil, status: nil}

  @create_message_attrs %{text: "some text"}
  @update_message_attrs %{text: "updated text"}
  @invalid_message_attrs %{text: nil}

  defp create_reservation(%{user: user}) do
    vehicle = vehicle_fixture()
    reservation = reservation_fixture(%{user: user, vehicle: vehicle})

    %{
      reservation: reservation,
      vehicle: vehicle,
      message: message_fixture(%{user: user, reservation: reservation})
    }
  end

  defp eventually_delete(view, message_id, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Stream.repeatedly(fn -> has_element?(view, "#messages-#{message_id}") end)
    |> Enum.reduce_while(nil, fn present, _ ->
      cond do
        not present ->
          {:halt, true}

        System.monotonic_time(:millisecond) > deadline ->
          {:halt, false}

        true ->
          Process.sleep(50)
          {:cont, nil}
      end
    end)
  end

  defp eventually_text(view, text, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Stream.repeatedly(fn -> render(view) end)
    |> Enum.reduce_while(nil, fn html, _ ->
      cond do
        String.contains?(html, text) ->
          {:halt, true}

        System.monotonic_time(:millisecond) > deadline ->
          {:halt, html}

        true ->
          Process.sleep(50)
          {:cont, nil}
      end
    end)
  end

  describe "Index" do
    setup [:register_log_in_and_confirm_user, :create_reservation]

    test "lists only appropriate reservations", %{conn: conn, reservation: this_users_reservation} do
      other_users_reservation = reservation_fixture()

      {:ok, index_live, html} = live(conn, ~p"/reservations")

      assert html =~ "Listing Reservations"

      refute has_element?(index_live, "#reservations-#{other_users_reservation.id}")
      assert has_element?(index_live, "#reservations-#{this_users_reservation.id}")
    end

    test "saves new reservation", %{conn: conn, vehicle: vehicle} do
      {:ok, vehicle_live, _html} = live(conn, ~p"/vehicles/#{vehicle}")

      assert vehicle_live |> element("a", "Book Reservation") |> render_click() =~
               "Book Reservation"

      {:ok, reservation_live, _html} = live(conn, ~p"/reservations/vehicles/#{vehicle}/new")

      assert reservation_live
             |> form("#reservation-form", reservation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert reservation_live
             |> form("#reservation-form", reservation: @create_attrs)
             |> render_submit()

      assert_patch(reservation_live, ~p"/reservations")

      html = render(reservation_live)
      assert html =~ "Reservation created successfully"
    end

    test "updates reservation in listing", %{conn: conn, reservation: reservation} do
      {:ok, index_live, _html} = live(conn, ~p"/reservations")

      assert index_live
             |> element("#reservations-#{reservation.id} a", "Edit")
             |> render_click() =~ "Edit Reservation"

      assert_patch(index_live, ~p"/reservations/#{reservation}/edit")

      assert index_live
             |> form("#reservation-form", reservation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#reservation-form", reservation: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/reservations")

      html = render(index_live)
      assert html =~ "Reservation updated successfully"

      assert index_live
             |> element("#reservations-#{reservation.id} a", "Edit")
             |> render_click() =~ "Edit Reservation"

      assert_raise ArgumentError, fn ->
        index_live
        |> form("#reservation-form", reservation: @admin_update_attrs)
        |> render_submit()
      end
    end

    test "deletes reservation in listing", %{conn: conn, reservation: reservation} do
      {:ok, index_live, _html} = live(conn, ~p"/reservations")

      assert index_live
             |> element("#reservations-#{reservation.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#reservations-#{reservation.id}")
    end
  end

  describe "Admin Index" do
    setup [:register_log_in_and_promote_user, :create_reservation]

    test "lists all avalible reservations", %{conn: conn, reservation: this_users_reservation} do
      other_users_reservation = reservation_fixture()

      {:ok, index_live, html} = live(conn, ~p"/reservations")

      assert html =~ "Listing Reservations"

      assert has_element?(index_live, "#reservations-#{other_users_reservation.id}")
      assert has_element?(index_live, "#reservations-#{this_users_reservation.id}")
    end
  end

  describe "Show" do
    setup [:register_log_in_and_confirm_user, :create_reservation]

    test "displays reservation", %{conn: conn, reservation: reservation} do
      {:ok, _show_live, html} = live(conn, ~p"/reservations/#{reservation}")

      assert html =~ "Show Reservation"
    end

    test "updates reservation within modal", %{conn: conn, reservation: reservation} do
      {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

      assert show_live |> element("a", "Edit Reservation") |> render_click() =~
               "Edit Reservation"

      assert_patch(show_live, ~p"/reservations/#{reservation}/show/edit")

      assert show_live
             |> form("#reservation-form", reservation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#reservation-form", reservation: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/reservations/#{reservation}")

      html = render(show_live)
      assert html =~ "Reservation updated successfully"

      assert show_live |> element("a", "Edit Reservation") |> render_click() =~
               "Edit Reservation"

      assert_raise ArgumentError, fn ->
        show_live
        |> form("#reservation-form", reservation: @admin_update_attrs)
        |> render_submit()
      end
    end
  end

  describe "Admin Show" do
    setup [:register_log_in_and_promote_user, :create_reservation]

    test "updates reservation within modal", %{conn: conn, reservation: reservation} do
      {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

      assert show_live |> element("a", "Edit Reservation") |> render_click() =~
               "Edit Reservation"

      assert_patch(show_live, ~p"/reservations/#{reservation}/show/edit")

      assert show_live
             |> form("#reservation-form", reservation: @admin_invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#reservation-form", reservation: @admin_update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/reservations/#{reservation}")

      html = render(show_live)
      assert html =~ "Reservation updated successfully"

      assert has_element?(show_live, "p", "Accepted")
    end
  end

  describe "Messages" do
    setup [:register_log_in_and_confirm_user, :create_reservation]

    test "displays messages", %{conn: conn, reservation: reservation} do
      {:ok, _show_live, html} = live(conn, ~p"/reservations/#{reservation}")

      assert html =~ "Messages"
    end

    test "saves new message", %{conn: conn, reservation: reservation} do
      {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

      assert show_live
             |> form("#messages-form", message: @invalid_message_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#messages-form", message: @create_message_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/reservations/#{reservation}")

      html = render(show_live)
      assert html =~ "Message sent successfully"
    end

    test "updates message within modal", %{conn: conn, reservation: reservation, message: message} do
      {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

      assert show_live
             |> element("a#messages-#{message.id}-edit")
             |> render_click() =~
               "Edit Message"

      assert_patch(show_live, ~p"/reservations/#{reservation}/messages/#{message}/edit")

      assert show_live
             |> form("#messages-edit-form", message: @invalid_message_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#messages-edit-form", message: @update_message_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/reservations/#{reservation}")

      html = render(show_live)
      assert html =~ "Message updated successfully"
    end

    test "deletes message in listing", %{conn: conn, reservation: reservation, message: message} do
      {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

      assert show_live
             |> element("a#messages-#{message.id}-delete")
             |> render_click()

      refute has_element?(show_live, "#messages-#{message.id}")
    end

    test "creates new message with pubsub", %{conn: conn, reservation: reservation, user: user} do
      {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

      message =
        message_fixture(%{reservation: reservation, user: user, text: "sent text"})
        |> Messages.preload_from()

      send(show_live.pid, {:new, message})

      assert eventually_text(show_live, "sent text")
    end

    test "updates message with pubsub", %{
      conn: conn,
      reservation: reservation,
      message: message
    } do
      {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

      {:ok, message} = Messages.update_message(message, %{text: "edited text"})
      message = Messages.preload_from(message)
      send(show_live.pid, {:edit, message})

      assert eventually_text(show_live, "edited text")
    end

    test "deletes message with pubsub", %{
      conn: conn,
      reservation: reservation,
      message: message
    } do
      {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

      send(show_live.pid, {:delete, message})

      assert eventually_delete(show_live, message.id)
    end

    property "generated edit sequence converges on final text", %{
      conn: conn,
      user: user,
      reservation: reservation,
      message: message
    } do
      check all(
              texts <-
                StreamData.list_of(
                  StreamData.string(:alphanumeric, min_length: 1, max_length: 40),
                  min_length: 2,
                  max_length: 6
                ),
              max_runs: 10
            ) do
        {:ok, show_live, _html} = live(conn, ~p"/reservations/#{reservation}")

        for text <- texts do
          {:ok, updated} = Messages.update_message(message, %{text: text})
          updated = Messages.preload_from(updated)

          Phoenix.PubSub.broadcast(
            NextGearMotors.PubSub,
            "messages:#{reservation.id}",
            {:edit, updated}
          )
        end

        html = render(show_live)

        assert Enum.any?(texts, &String.contains?(html, &1)),
               "none of the broadcast edits landed: #{inspect(texts)}"
      end
    end
  end
end
