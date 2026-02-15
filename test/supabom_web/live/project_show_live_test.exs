defmodule SupabomWeb.ProjectShowLiveTest do
  use SupabomWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Supabom.Projects.Dependency
  alias Supabom.Projects.Project
  alias Supabom.Projects.ProjectVersion

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

    # Dependencies should be collapsed by default
    refute has_element?(view, "#dependencies-table")
    assert render(view) =~ "1 packages"

    # Expand the dependencies
    view |> element(".dependency-summary-card") |> render_click()

    # Now the table should be visible
    assert has_element?(view, "#dependencies-table")
    assert render(view) =~ "phoenix"
    assert render(view) =~ "1.8.3"

    # Collapse the dependencies again
    view |> element(".dependency-summary-card") |> render_click()

    # Table should be hidden again
    refute has_element?(view, "#dependencies-table")
  end

  test "shows upload new version button and modal", %{conn: conn} do
    {:ok, project} =
      Project
      |> Ash.Changeset.for_create(:create, %{name: "Test Project", ecosystem: "elixir"})
      |> Ash.create(authorize?: false)

    {:ok, version} =
      ProjectVersion
      |> Ash.Changeset.for_create(:create, %{
        project_id: project.id,
        version_number: 1,
        project_version: "1.0.0",
        elixir_version: "1.15.0"
      })
      |> Ash.create(authorize?: false)

    {:ok, _dependency} =
      Dependency
      |> Ash.Changeset.for_create(:create, %{
        project_id: project.id,
        project_version_id: version.id,
        package: "phoenix",
        version: "1.8.3",
        manager: "hex"
      })
      |> Ash.create(authorize?: false)

    {:ok, view, _html} =
      live_isolated(conn, SupabomWeb.ProjectShowLive, session: %{"id" => project.id})

    # Upload button should be present
    assert has_element?(view, "#upload-new-lockfile-btn", "Upload New Version")

    # Version info should be displayed (shows project_version from mix.exs)
    assert has_element?(view, ".version-badge", "Version 1.0.0")

    # Modal should not be visible initially
    refute has_element?(view, "#upload-modal")

    # Click the upload button to open modal
    view |> element("#upload-new-lockfile-btn") |> render_click()

    # Modal should now be visible
    assert has_element?(view, "#upload-modal")
    assert has_element?(view, ".modal-header h2", "Upload New Version")
    assert has_element?(view, "#version-upload-form")

    # Close modal using the X button
    view |> element(".modal-close") |> render_click()

    # Modal should be hidden again
    refute has_element?(view, "#upload-modal")
  end

  test "upload version form registers mix.lock selection", %{conn: conn} do
    {:ok, project} =
      Project
      |> Ash.Changeset.for_create(:create, %{name: "Upload Project", ecosystem: "elixir"})
      |> Ash.create(authorize?: false)

    {:ok, view, _html} =
      live_isolated(conn, SupabomWeb.ProjectShowLive, session: %{"id" => project.id})

    view |> element("#upload-new-lockfile-btn") |> render_click()

    upload =
      file_input(view, "#version-upload-form", :lockfile, [
        %{
          name: "mix.lock",
          content: """
          %{
            "jason" => {:hex, :jason, "1.4.4", "hash", [:mix], [], "hexpm", "outer"}
          }
          """,
          type: "text/plain"
        }
      ])

    assert render_upload(upload, "mix.lock")

    view |> element("#version-upload-form") |> render_submit(%{})

    # If lockfile upload registered, the next blocking validation is mix.exs.
    assert render(view) =~ "Please select a mix.exs file to upload"
  end
end
