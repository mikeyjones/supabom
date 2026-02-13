defmodule SupabomWeb.ProjectNewLiveTest do
  use SupabomWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Supabom.Projects.Project

  test "renders create project form with both file inputs", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, SupabomWeb.ProjectNewLive)

    assert has_element?(view, "#project-form")
    assert has_element?(view, "input[type='file']")
    assert has_element?(view, "#project-submit-btn")

    # Check that we have two file inputs (one for lockfile, one for mixexs)
    html = render(view)
    assert html =~ "mix.lock File"
    assert html =~ "mix.exs File"
  end

  test "shows error when submitting without lockfile", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, SupabomWeb.ProjectNewLive)

    view
    |> element("#project-form")
    |> render_submit(%{"project" => %{"name" => "Demo"}})

    assert has_element?(view, "#project-form-error")
    assert render(view) =~ "Please upload a mix.lock file"
  end

  test "shows error when submitting without mix.exs", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, SupabomWeb.ProjectNewLive)

    # Upload mix.lock but not mix.exs
    upload =
      file_input(view, "#project-form", :lockfile, [
        %{
          name: "mix.lock",
          content:
            "%{\"jason\" => {:hex, :jason, \"1.4.4\", \"hash\", [:mix], [], \"hexpm\", \"outer\"}}",
          type: "text/plain"
        }
      ])

    assert render_upload(upload, "mix.lock")

    view
    |> element("#project-form")
    |> render_submit(%{"project" => %{"name" => "Demo"}})

    assert has_element?(view, "#project-form-error")
    assert render(view) =~ "Please upload a mix.exs file"
  end

  test "shows error when uploading wrong filename for mix.exs", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, SupabomWeb.ProjectNewLive)

    # Upload mix.lock correctly
    lockfile_upload =
      file_input(view, "#project-form", :lockfile, [
        %{
          name: "mix.lock",
          content:
            "%{\"jason\" => {:hex, :jason, \"1.4.4\", \"hash\", [:mix], [], \"hexpm\", \"outer\"}}",
          type: "text/plain"
        }
      ])

    assert render_upload(lockfile_upload, "mix.lock")

    # Upload wrong filename for mix.exs
    mixexs_upload =
      file_input(view, "#project-form", :mixexs, [
        %{
          name: "wrong_name.txt",
          content: "defmodule MyApp.MixProject do\nend",
          type: "text/plain"
        }
      ])

    assert render_upload(mixexs_upload, "wrong_name.txt")

    view
    |> element("#project-form")
    |> render_submit(%{"project" => %{"name" => "Demo"}})

    assert has_element?(view, "#project-form-error")
    assert render(view) =~ "Please upload a file named mix.exs"
  end

  test "creates project with version info after uploading both files", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, SupabomWeb.ProjectNewLive)

    # Upload mix.lock
    lockfile_upload =
      file_input(view, "#project-form", :lockfile, [
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

    assert render_upload(lockfile_upload, "mix.lock")

    # Upload mix.exs
    mixexs_upload =
      file_input(view, "#project-form", :mixexs, [
        %{
          name: "mix.exs",
          content: """
          defmodule MyApp.MixProject do
            use Mix.Project

            def project do
              [
                app: :my_app,
                version: "1.2.3",
                elixir: "~> 1.15"
              ]
            end
          end
          """,
          type: "text/plain"
        }
      ])

    assert render_upload(mixexs_upload, "mix.exs")

    view
    |> element("#project-form")
    |> render_submit(%{"project" => %{"name" => "Upload Test"}})

    {redirect_path, _flash} = assert_redirect(view)
    assert String.starts_with?(redirect_path, "/projects/")

    project =
      Project
      |> Ash.read!(authorize?: false)
      |> Enum.find(fn existing_project -> existing_project.name == "Upload Test" end)

    assert project
    assert project.name == "Upload Test"
    assert project.project_version == "1.2.3"
    assert project.elixir_version == "~> 1.15"
  end
end
