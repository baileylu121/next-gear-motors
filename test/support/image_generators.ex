defmodule NextGearMotors.ImageGenerators do
  @moduledoc """
  Test support for helping generate feasible input packets for property
  testing the vehicles fixtures covers uploads.
  """
  @fixture "test/support/fixtures/vehicles_fixtures/car.jpg"

  def valid_jpeg_bytes, do: File.read!(@fixture)

  def plug_upload(bytes, name \\ "photo.jpg", type \\ "image/jpeg") do
    tmp = Path.join(System.tmp_dir!(), "ngm-upload-#{System.unique_integer([:positive])}-#{name}")
    File.write!(tmp, bytes)

    {tmp,
     %Plug.Upload{
       path: tmp,
       filename: name,
       content_type: type
     }}
  end

  def upload_map(bytes, name \\ "photo.jpg", type \\ "image/jpeg") do
    %{name: name, content: bytes, type: type}
  end

  def register_cleanup(tmp_path) do
    ExUnit.Callbacks.on_exit(fn -> File.rm(tmp_path) end)
  end

  def corrupt_bytes do
    StreamData.binary(length: 100..5000)
  end

  def truncated_jpeg do
    full = valid_jpeg_bytes()
    half = byte_size(full) |> div(2) |> then(&:binary.part(full, 0, &1))

    splice_at = div(byte_size(half), 2)

    spliced =
      :binary.part(half, 0, splice_at) <>
        :rand.bytes(64) <> :binary.part(half, splice_at, byte_size(half) - splice_at)

    {half, spliced}
  end

  def oversized_map do
    full = valid_jpeg_bytes()
    repeats = div(13_000_000, byte_size(full)) + 1

    padded =
      Stream.repeatedly(fn -> full end)
      |> Enum.take(repeats)
      |> IO.iodata_to_binary()
      |> binary_part(0, 13_000_000)

    upload_map(padded, "big.jpg", "image/jpeg")
  end

  def bad_extension_map do
    StreamData.member_of(["photo.heic", "photo.gif", "photo.webp"])
    |> StreamData.map(&upload_map(valid_jpeg_bytes(), &1, "image/jpeg"))
  end

  def batch_sizes do
    StreamData.integer(1..20)
  end
end
