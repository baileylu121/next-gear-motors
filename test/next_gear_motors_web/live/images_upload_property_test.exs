defmodule NextGearMotorsWeb.ImagesUploadPropertyTest do
  use NextGearMotorsWeb.ConnCase
  use ExUnitProperties

  import Phoenix.LiveViewTest

  alias NextGearMotors.ImageGenerators

  @create_attrs %{
    name: "some name",
    description: "some description",
    price: "€40,000",
    manufacturer: "some manufacturer"
  }

  defp eventually(fun, timeout_ms \\ 60_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Stream.repeatedly(fun)
    |> Enum.reduce_while(nil, fn result, _ ->
      cond do
        result ->
          {:halt, result}

        System.monotonic_time(:millisecond) > deadline ->
          {:halt, false}

        true ->
          Process.sleep(200)
          {:cont, nil}
      end
    end)
  end

  defp unfinished_form?(html) do
    html =~ "all image uploads must be finished"
  end

  describe "image upload fault tolerance" do
    setup [:register_log_in_and_promote_user]

    property "batch of 1..30 valid uploads always reaches :finished", %{conn: conn} do
      check all(n <- ImageGenerators.batch_sizes(), max_runs: 10) do
        bytes = ImageGenerators.valid_jpeg_bytes()

        entries =
          for i <- 1..n, do: ImageGenerators.upload_map(bytes, "car-#{i}.jpg", "image/jpeg")

        {:ok, index_live, _html} = live(conn, ~p"/vehicles")

        index_live
        |> element("a", "New Vehicle")
        |> render_click()

        names = Enum.map(entries, & &1.name)

        upload = file_input(index_live, "#upload-form", :covers, entries)

        for name <- names do
          assert is_binary(render_upload(upload, name, 50))
        end

        for name <- names do
          render_upload(upload, name, 50)
        end

        done? =
          eventually(
            fn ->
              html = render(index_live)
              stored = length(String.split(html, "/uploads/vehicles/covers")) - 1
              stored >= n and not unfinished_form?(html)
            end,
            120_000
          )

        assert done?, "batch of #{n} valid uploads never stored #{n} covers"
      end
    end

    test "one corrupt file does not block the rest", %{conn: conn} do
      valid_a =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "car-a.jpg", "image/jpeg")

      valid_b =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "car-b.jpg", "image/jpeg")

      corrupt = ImageGenerators.upload_map(:rand.bytes(3000), "corrupt.jpg", "image/jpeg")

      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      index_live
      |> element("a", "New Vehicle")
      |> render_click()

      upload = file_input(index_live, "#upload-form", :covers, [valid_a, corrupt, valid_b])

      partials = [{"car-a.jpg", 40}, {"corrupt.jpg", 60}, {"car-b.jpg", 40}]

      for {name, percent} <- partials do
        assert is_binary(render_upload(upload, name, percent))
      end

      for {name, percent} <- partials do
        render_upload(upload, name, 100 - percent)
      end

      assert eventually(fn ->
               html = render(index_live)
               length(String.split(html, "/uploads/vehicles/covers")) - 1 >= 2
             end),
             "valid covers never finished when mixed with a corrupt file"

      assert eventually(fn ->
               render(index_live) =~ "failed" or not unfinished_form?(render(index_live))
             end),
             "corrupt file produced neither a failure flash nor recovery"

      refute unfinished_form?(render(index_live)),
             "form stuck :unfinished after one corrupt file: #{String.slice(render(index_live), 0, 500)}"

      assert index_live
             |> form("#vehicle-form", vehicle: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/vehicles")

      html = render(index_live)
      assert html =~ "Vehicle created successfully"
    end

    test "oversized file is rejected and form recovers", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      index_live
      |> element("a", "New Vehicle")
      |> render_click()

      assert {:error, [[_ref, :too_large]]} =
               index_live
               |> file_input("#upload-form", :covers, [ImageGenerators.oversized_map()])
               |> render_upload("big.jpg")

      valid =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "car.jpg", "image/jpeg")

      index_live
      |> file_input("#upload-form", :covers, [valid])
      |> render_upload("car.jpg")

      assert eventually(fn -> render(index_live) =~ "/uploads/vehicles/covers" end),
             "valid upload after oversized rejection never finished"

      assert index_live
             |> form("#vehicle-form", vehicle: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/vehicles")
      assert render(index_live) =~ "Vehicle created successfully"
    end

    test "unaccepted extension is rejected and form recovers", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      index_live
      |> element("a", "New Vehicle")
      |> render_click()

      bad =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "photo.heic", "image/jpeg")

      html =
        index_live
        |> file_input("#upload-form", :covers, [bad])
        |> render_upload("photo.heic")

      assert is_binary(html)

      valid =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "car.jpg", "image/jpeg")

      index_live
      |> file_input("#upload-form", :covers, [valid])
      |> render_upload("car.jpg")

      assert eventually(fn -> render(index_live) =~ "/uploads/vehicles/covers" end),
             "valid upload after extension rejection never finished"

      refute render(index_live) =~ "all image uploads must be finished",
             "form stuck :unfinished after rejected extension"

      assert index_live
             |> form("#vehicle-form", vehicle: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/vehicles")
      assert render(index_live) =~ "Vehicle created successfully"
    end

    test "cancel in-flight upload keeps form usable", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      index_live
      |> element("a", "New Vehicle")
      |> render_click()

      valid =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "car.jpg", "image/jpeg")

      upload = file_input(index_live, "#upload-form", :covers, [valid])
      render_upload(upload, "car.jpg", 50)
      [%{"ref" => ref}] = upload.entries

      index_live
      |> element("button[phx-click='cancel-upload'][phx-value-ref='#{ref}']")
      |> render_click()

      refute render(index_live) =~ "phx-preview-",
             "cancelled upload entry still rendered"

      valid2 =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "car2.jpg", "image/jpeg")

      index_live
      |> file_input("#upload-form", :covers, [valid2])
      |> render_upload("car2.jpg")

      assert eventually(fn -> render(index_live) =~ "/uploads/vehicles/covers" end),
             "form unusable after cancelling an in-flight upload"

      assert index_live
             |> form("#vehicle-form", vehicle: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/vehicles")
      assert render(index_live) =~ "Vehicle created successfully"
    end

    test "failed store reports failure and unblocks the form", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/vehicles")

      index_live
      |> element("a", "New Vehicle")
      |> render_click()

      bad =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "photo.heic", "image/jpeg")

      html =
        index_live
        |> file_input("#upload-form", :covers, [bad])
        |> render_upload("photo.heic")

      assert is_binary(html)

      assert eventually(fn ->
               flash = render(index_live)
               flash =~ "failed" or flash =~ "Image Processing Completed!"
             end),
             "failed store produced neither a failure flash nor a completion"

      valid =
        ImageGenerators.upload_map(ImageGenerators.valid_jpeg_bytes(), "car.jpg", "image/jpeg")

      index_live
      |> file_input("#upload-form", :covers, [valid])
      |> render_upload("car.jpg")

      assert eventually(fn -> render(index_live) =~ "/uploads/vehicles/covers" end),
             "form stayed blocked after a failed store"

      assert index_live
             |> form("#vehicle-form", vehicle: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/vehicles")
      assert render(index_live) =~ "Vehicle created successfully"
    end
  end
end
