defmodule NextGearMotorsWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use NextGearMotorsWeb, :html

  import NextGearMotorsWeb.Components.Carousel
  alias NextGearMotors.Vehicles.Covers.Cover

  embed_templates "page_html/*"
end
