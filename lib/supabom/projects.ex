defmodule Supabom.Projects do
  @moduledoc """
  The Projects domain, responsible for uploaded lockfiles and parsed dependencies.
  """

  use Ash.Domain

  resources do
    resource(Supabom.Projects.Project)
    resource(Supabom.Projects.Dependency)
  end
end
