defmodule SupabomWeb.ProjectShowLiveTest do
  use SupabomWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Supabom.Projects.Dependency
  alias Supabom.Projects.Project

  test "renders dependency table for project", %{conn: conn} do
    {:ok, project} =
      Project
      |> Ash.Changeset.for_create(:create, %{name: "Demo Project", ecosystem: "elixir"})
      |> Ash.create(authorize?: false)

    {:ok, _dependency} =
      Dependency
      |> Ash.Changeset.for_create(:create, %{
        project_id: project.id,
        package: "phoenix",
        version: "1.8.3",
        manager: "hex"
      })
      |> Ash.create(authorize?: false)

    {:ok, view, _html} =
      live_isolated(conn, SupabomWeb.ProjectShowLive, session: %{"id" => project.id})

    assert has_element?(view, "#dependencies-table")
    assert render(view) =~ "phoenix"
    assert render(view) =~ "1.8.3"
  end
end
