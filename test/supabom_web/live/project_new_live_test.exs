defmodule SupabomWeb.ProjectNewLiveTest do
  use SupabomWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Supabom.Projects.Project

  setup do
    previous_client = Application.get_env(:supabom, :github_client)
    previous_response = Application.get_env(:supabom, :github_client_mock_response)

    Application.put_env(:supabom, :github_client, Supabom.TestSupport.GitHubClientMock)
    Application.delete_env(:supabom, :github_client_mock_response)

    on_exit(fn ->
      if previous_client do
        Application.put_env(:supabom, :github_client, previous_client)
      else
        Application.delete_env(:supabom, :github_client)
      end

      if previous_response do
        Application.put_env(:supabom, :github_client_mock_response, previous_response)
      else
        Application.delete_env(:supabom, :github_client_mock_response)
      end
    end)

    :ok
  end

  test "renders github repository form", %{conn: conn} do
    {:ok, view, _html} =
      live_isolated(conn, SupabomWeb.ProjectNewLive,
        session: %{"github_installation_id" => "123"}
      )

    assert has_element?(view, "#project-form")
    assert has_element?(view, "#connect-github-btn")
    assert has_element?(view, "#project-submit-btn")
    assert render(view) =~ "Repository (owner/repo or GitHub URL)"
  end

  test "shows error when installation is missing", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, SupabomWeb.ProjectNewLive)

    view
    |> element("#project-form")
    |> render_submit(%{"project" => %{"name" => "Demo", "repository" => "elixir-lang/elixir"}})

    assert has_element?(view, "#project-form-error")
    assert render(view) =~ "Please connect a GitHub App installation first"
  end

  test "creates project and imports first version from github", %{conn: conn} do
    {:ok, view, _html} =
      live_isolated(conn, SupabomWeb.ProjectNewLive,
        session: %{"github_installation_id" => "123"}
      )

    view
    |> element("#project-form")
    |> render_submit(%{
      "project" => %{"name" => "Upload Test", "repository" => "elixir-lang/elixir"}
    })

    {redirect_path, _flash} = assert_redirect(view)
    assert String.starts_with?(redirect_path, "/projects/")

    project =
      Project
      |> Ash.read!(authorize?: false)
      |> Enum.find(fn existing_project -> existing_project.name == "Upload Test" end)

    assert project
    assert project.name == "Upload Test"
    assert project.project_version == "0.1.0"
    assert project.elixir_version == "~> 1.15"
  end
end
