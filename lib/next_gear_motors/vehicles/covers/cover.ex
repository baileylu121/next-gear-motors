defmodule NextGearMotors.Vehicles.Covers.Cover do
  @moduledoc """
  # Vehicle Cover Schema

  A `Cover` is the displayable image associated with a vehicle
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias Image

  @versions [:original]
  @extensions ~w(.png .jpg .jpeg)

  def validate({%Waffle.File{} = file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    if Enum.member?(@extensions, file_extension),
      do: :ok,
      else:
        {:error,
         "extension found on #{file.path} was not contained within #{inspect(@extensions)}"}
  end

  def transform(version, _) when version in @versions,
    do: {&to_webp/2, fn _, _ -> :webp end}

  defp to_webp(_version, %Waffle.File{} = file) do
    new_path = Waffle.File.generate_temporary_path("webp")

    with {:ok, image} <- Image.open(file.path),
         {:ok, {image, _flags}} <- Image.autorotate(image),
         {:ok, _image} <-
           Image.write(image, new_path, strip_metadata: true, minimize_file_size: true, effort: 8) do
      {:ok,
       %Waffle.File{
         file
         | path: new_path,
           is_tempfile?: true
       }}
    end
  end

  def filename(_version, {file, _vehicle}) do
    :crypto.hash_init(:sha512)
    |> :crypto.hash_update(file.file_name)
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  def storage_dir(_version, {_file, _scope}) do
    "/uploads/vehicles/covers/"
  end
end
