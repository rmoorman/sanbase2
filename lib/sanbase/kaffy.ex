defmodule Sanbase.Kaffy do
  # The kaffy admin uses String.to_existing_atom and fails if there is no atom. Add a bunch of atoms that are needed here.
  @atoms [:accounts]

  # define a public function so we don't get warnings about the unused module attribute
  def __atoms(), do: @atoms
end
