defmodule SupabomWeb.ProjectShowLive do
  use SupabomWeb, :live_view

  alias Supabom.Integrations.GitHub.RepoRef
  alias Supabom.Projects.Project
  alias Supabom.Projects.ProjectVersion
  alias Supabom.Projects.RepoImporter
  alias Supabom.Projects.RepositoryConnection

  @impl true
  def mount(%{"id" => id}, session, socket) do
    load_project(socket, id, session)
  end

  def mount(:not_mounted_at_router, %{"id" => id} = session, socket) do
    load_project(socket, id, session)
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Project not found")
     |> push_navigate(to: ~p"/dashboard")}
  end

  defp load_project(socket, id, session) do
    case Ash.get(Project, id,
           load: [:repository_connection, versions: [:dependencies]],
           authorize?: false
         ) do
      {:ok, nil} ->
        {:ok,
         socket
         |> put_flash(:error, "Project not found")
         |> push_navigate(to: ~p"/dashboard")}

      {:ok, project} ->
        current_version = get_current_version(project)
        dependencies = current_version_dependencies(current_version)
        repository_connection = project.repository_connection

        installation_id =
          session["github_installation_id"] ||
            (repository_connection && repository_connection.installation_id)

        install_url = Application.get_env(:supabom, :github_app, [])[:install_url]

        socket =
          socket
          |> assign(:page_title, project.name)
          |> assign(:current_scope, nil)
          |> assign(:project, project)
          |> assign(:current_version, current_version)
          |> assign(:dependencies, dependencies)
          |> assign(:versions, project.versions)
          |> assign(:dependencies_collapsed, false)
          |> assign(:installation_id, parse_installation_id(installation_id))
          |> assign(:github_install_configured?, is_binary(install_url) and install_url != "")
          |> assign(:repo_form, repo_form(repository_connection))

        {:ok, socket}

      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, "Could not load project")
         |> push_navigate(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("save_repo_connection", %{"repo" => params}, socket) do
    with {:ok, installation_id} <- validate_installation(socket.assigns.installation_id),
         {:ok, repo_ref} <- RepoRef.parse(params["repository"] || ""),
         {:ok, _connection} <-
           upsert_repository_connection(socket.assigns.project, repo_ref, installation_id) do
      {:noreply,
       socket
       |> put_flash(:info, "Repository connection saved")
       |> push_navigate(to: ~p"/projects/#{socket.assigns.project.id}")}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("import_from_github", _params, socket) do
    case socket.assigns.project.repository_connection do
      nil ->
        {:noreply, put_flash(socket, :error, "Save a repository connection first")}

      connection ->
        case RepoImporter.import_new_version(socket.assigns.project, connection) do
          {:ok, _version} ->
            {:noreply,
             socket
             |> put_flash(:info, "Imported latest manifests from GitHub")
             |> push_navigate(to: ~p"/projects/#{socket.assigns.project.id}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, reason)}
        end
    end
  end

  @impl true
  def handle_event("switch_version", %{"version_id" => version_id}, socket) do
    case Ash.get(ProjectVersion, version_id, load: [:dependencies], authorize?: false) do
      {:ok, version} ->
        dependencies = Enum.sort_by(version.dependencies, &{&1.package, &1.version})

        socket =
          socket
          |> assign(:current_version, version)
          |> assign(:dependencies, dependencies)
          |> assign(:dependencies_collapsed, false)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not load version")}
    end
  end

  defp get_current_version(project) do
    case project.versions do
      [version | _] -> version
      [] -> nil
    end
  end

  defp current_version_dependencies(nil), do: []

  defp current_version_dependencies(version) do
    Enum.sort_by(version.dependencies, fn dependency ->
      {dependency.package, dependency.version}
    end)
  end

  defp repo_form(nil), do: to_form(%{"repository" => ""}, as: :repo)

  defp repo_form(connection),
    do: to_form(%{"repository" => "#{connection.owner}/#{connection.repo}"}, as: :repo)

  defp upsert_repository_connection(project, repo_ref, installation_id) do
    attrs = %{
      owner: repo_ref.owner,
      repo: repo_ref.repo,
      installation_id: installation_id,
      sync_status: "pending",
      sync_error: nil
    }

    case project.repository_connection do
      nil ->
        params = Map.merge(attrs, %{project_id: project.id, provider: "github"})

        case RepositoryConnection
             |> Ash.Changeset.for_create(:create, params)
             |> Ash.create(authorize?: false) do
          {:ok, _connection} -> {:ok, :created}
          {:error, _error} -> {:error, "Could not create repository connection"}
        end

      connection ->
        case connection
             |> Ash.Changeset.for_update(:update, attrs)
             |> Ash.update(authorize?: false) do
          {:ok, _connection} -> {:ok, :updated}
          {:error, _error} -> {:error, "Could not update repository connection"}
        end
    end
  end

  defp validate_installation(nil), do: {:error, "Connect GitHub App first"}
  defp validate_installation(id), do: {:ok, id}

  defp parse_installation_id(nil), do: nil
  defp parse_installation_id(id) when is_integer(id), do: id

  defp parse_installation_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, _} -> value
      :error -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <.header>
          {@project.name}
          <:subtitle>
            <span :if={@project.project_version} class="text-sm font-semibold">
              v{@project.project_version}
            </span>
            <span :if={@project.elixir_version} class="text-sm">
              Elixir {@project.elixir_version}
            </span>
            <span class="text-sm">{length(@dependencies)} dependencies</span>
          </:subtitle>
          <:actions>
            <div class="flex gap-3">
              <a
                href={~p"/github/connect?return_to=/projects/#{@project.id}"}
                class="btn btn-outline"
                id="connect-github-btn"
              >
                Connect GitHub App
              </a>
              <button phx-click="import_from_github" class="btn btn-primary" id="import-github-btn">
                Import New Version
              </button>
              <a href={~p"/dashboard"} class="btn btn-ghost" id="back-to-dashboard-btn">Back</a>
            </div>
          </:actions>
        </.header>

        <div
          class="card bg-base-200 border border-base-300 p-4 space-y-3"
          id="repository-connection-card"
        >
          <p class="text-sm">
            Connected installation: <strong :if={@installation_id}>{@installation_id}</strong>
            <span :if={!@installation_id and @github_install_configured?} class="text-error">
              none
            </span>
            <span :if={!@installation_id and !@github_install_configured?} class="text-error">
              none (set `GITHUB_APP_INSTALL_URL`)
            </span>
          </p>

          <.form
            for={@repo_form}
            id="repo-connection-form"
            phx-submit="save_repo_connection"
            class="space-y-3"
          >
            <.input
              field={@repo_form[:repository]}
              type="text"
              label="Repository (owner/repo or GitHub URL)"
              required
            />
            <button class="btn btn-secondary" id="save-repo-connection-btn" type="submit">
              Save Connection
            </button>
          </.form>
        </div>

        <div :if={@versions != []} class="card bg-base-200 border border-base-300 p-4 space-y-2">
          <label class="font-semibold" for="version-switcher">Project versions</label>
          <select
            id="version-switcher"
            class="select select-bordered w-full max-w-xs"
            phx-change="switch_version"
            name="version_id"
          >
            <option
              :for={version <- @versions}
              value={version.id}
              selected={@current_version && @current_version.id == version.id}
            >
              v{version.project_version || version.version_number}
            </option>
          </select>
        </div>

        <div :if={@dependencies == []} class="alert" id="empty-dependencies-state">
          <span>No dependencies found yet. Import from GitHub to populate this project.</span>
        </div>

        <%= if @dependencies != [] do %>
          <div class="overflow-x-auto" id="dependencies-container">
            <table class="table table-zebra" id="dependencies-table">
              <thead>
                <tr>
                  <th>Package</th>
                  <th>Version</th>
                  <th>Source</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={dependency <- @dependencies}>
                  <td>{dependency.package}</td>
                  <td><code>{dependency.version}</code></td>
                  <td>{dependency.manager}</td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>
    </Layouts.app>
    """
  end
end
