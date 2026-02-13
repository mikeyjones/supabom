defmodule SupabomWeb.ProjectShowLive do
  use SupabomWeb, :live_view

  alias Supabom.Projects.Project

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    load_project(socket, id)
  end

  def mount(:not_mounted_at_router, %{"id" => id}, socket) do
    load_project(socket, id)
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Project not found")
     |> push_navigate(to: ~p"/dashboard")}
  end

  defp load_project(socket, id) do
    case Ash.get(Project, id, load: [:dependencies], authorize?: false) do
      {:ok, nil} ->
        {:ok,
         socket
         |> put_flash(:error, "Project not found")
         |> push_navigate(to: ~p"/dashboard")}

      {:ok, project} ->
        dependencies =
          project.dependencies
          |> Enum.sort_by(fn dependency -> {dependency.package, dependency.version} end)

        socket =
          socket
          |> assign(:page_title, project.name)
          |> assign(:current_scope, nil)
          |> assign(:project, project)
          |> assign(:dependencies, dependencies)

        {:ok, socket}

      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, "Could not load project")
         |> push_navigate(to: ~p"/dashboard")}
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
            <div class="flex gap-3 items-center flex-wrap">
              <span class="badge badge-primary badge-outline">mix.lock</span>
              <span :if={@project.project_version} class="text-sm font-semibold">
                v{@project.project_version}
              </span>
              <span :if={@project.elixir_version} class="text-sm text-base-content/70">
                Elixir {@project.elixir_version}
              </span>
              <span class="text-sm">{length(@dependencies)} dependencies</span>
            </div>
          </:subtitle>
          <:actions>
            <.button navigate={~p"/projects/new"} id="upload-new-lockfile-btn">
              Upload New mix.lock
            </.button>
            <.button navigate={~p"/dashboard"} id="back-to-dashboard-btn">Back to Dashboard</.button>
          </:actions>
        </.header>

        <div :if={@dependencies == []} class="alert alert-info" id="empty-dependencies-state">
          No dependencies were found in the uploaded lockfile.
        </div>

        <div
          :if={@dependencies != []}
          class="overflow-x-auto rounded-xl border border-base-300 bg-base-100"
        >
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
                <td class="font-semibold">{dependency.package}</td>
                <td><code>{dependency.version}</code></td>
                <td><span class="badge badge-ghost">{dependency.manager}</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
