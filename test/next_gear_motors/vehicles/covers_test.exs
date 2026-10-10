defmodule NextGearMotors.Vehicles.CoversTest do
  use NextGearMotors.DataCase
  use ExUnitProperties

  alias NextGearMotors.ImageGenerators
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

  describe "covers" do
    @img "test/support/fixtures/vehicles_fixtures/car.jpg"

    test "store creates an image" do
      {:ok, "car.jpg"} = Cover.store(@img)
    end

    property "store never raises on random bytes" do
      check all(bytes <- ImageGenerators.corrupt_bytes(), max_runs: 25) do
        {tmp, upload} = ImageGenerators.plug_upload(bytes, "random.jpg", "image/jpeg")
        ImageGenerators.register_cleanup(tmp)

        assert (case Cover.store(upload) do
                  {:ok, _} -> true
                  {:error, _} -> true
                end)
      end
    end

    property "store never raises on truncated jpeg bytes" do
      {half, spliced} = ImageGenerators.truncated_jpeg()

      check all(bytes <- StreamData.member_of([half, spliced]), max_runs: 2) do
        {tmp, upload} = ImageGenerators.plug_upload(bytes, "trunc.jpg", "image/jpeg")
        ImageGenerators.register_cleanup(tmp)

        assert (case Cover.store(upload) do
                  {:ok, _} -> true
                  {:error, _} -> true
                end)
      end
    end

    test "empty input is an error tuple, not a crash" do
      {tmp, upload} = ImageGenerators.plug_upload(<<>>, "empty.jpg", "image/jpeg")
      ImageGenerators.register_cleanup(tmp)

      assert {:error, _} = Cover.store(upload)
    end
  end
end
