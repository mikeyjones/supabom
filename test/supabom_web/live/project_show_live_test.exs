defmodule SupabomWeb.ProjectShowLiveTest do
  use SupabomWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Supabom.Projects.Dependency
  alias Supabom.Projects.Project
  alias Supabom.Projects.ProjectVersion
  alias Supabom.Projects.RepositoryConnection

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

  test "renders dependency table for current version", %{conn: conn} do
    {:ok, project} =
      Project
      |> Ash.Changeset.for_create(:create, %{name: "Demo Project", ecosystem: "elixir"})
      |> Ash.create(authorize?: false)

    {:ok, version} =
      ProjectVersion
      |> Ash.Changeset.for_create(:create, %{
        project_id: project.id,
        version_number: 1,
        project_version: "1.0.0",
        elixir_version: "~> 1.15"
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
      live_isolated(conn, SupabomWeb.ProjectShowLive,
        session: %{"id" => project.id, "github_installation_id" => "123"}
      )

    assert has_element?(view, "#dependencies-table")
    assert render(view) =~ "phoenix"
    assert render(view) =~ "1.8.3"
  end

  test "saves repository connection from form", %{conn: conn} do
    {:ok, project} =
      Project
      |> Ash.Changeset.for_create(:create, %{name: "Test Project", ecosystem: "elixir"})
      |> Ash.create(authorize?: false)

    {:ok, view, _html} =
      live_isolated(conn, SupabomWeb.ProjectShowLive,
        session: %{"id" => project.id, "github_installation_id" => "321"}
      )

    view
    |> element("#repo-connection-form")
    |> render_submit(%{"repo" => %{"repository" => "elixir-lang/elixir"}})

    connection =
      RepositoryConnection
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.project_id == project.id))

    assert connection
    assert connection.owner == "elixir-lang"
    assert connection.repo == "elixir"
    assert connection.installation_id == 321
  end

  test "imports a new version from github connection", %{conn: conn} do
    {:ok, project} =
      Project
      |> Ash.Changeset.for_create(:create, %{name: "Upload Project", ecosystem: "elixir"})
      |> Ash.create(authorize?: false)

    {:ok, _connection} =
      RepositoryConnection
      |> Ash.Changeset.for_create(:create, %{
        project_id: project.id,
        provider: "github",
        owner: "elixir-lang",
        repo: "elixir",
        installation_id: 55
      })
      |> Ash.create(authorize?: false)

    {:ok, view, _html} =
      live_isolated(conn, SupabomWeb.ProjectShowLive, session: %{"id" => project.id})

    view |> element("#import-github-btn") |> render_click()
    assert_redirect(view)

    project_version =
      ProjectVersion
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.project_id == project.id))

    assert project_version

    dependencies =
      Dependency
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.project_id == project.id))

    assert Enum.any?(dependencies, &(&1.package == "jason"))
  end
end
