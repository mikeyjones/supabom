defmodule SupabomWeb.ProjectNewLive do
  use SupabomWeb, :live_view

  alias Supabom.Integrations.GitHub.RepoRef
  alias Supabom.Projects.Project
  alias Supabom.Projects.RepoImporter
  alias Supabom.Projects.RepositoryConnection

  @impl true
  def mount(_params, session, socket) do
    installation_id = parse_installation_id(session["github_installation_id"])
    install_url = Application.get_env(:supabom, :github_app, [])[:install_url]

    socket =
      socket
      |> assign(:page_title, "Create Project")
      |> assign(:current_scope, nil)
      |> assign(:form, to_form(%{"name" => "", "repository" => ""}, as: :project))
      |> assign(:error_message, nil)
      |> assign(:installation_id, installation_id)
      |> assign(:github_install_configured?, is_binary(install_url) and install_url != "")

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"project" => params}, socket) do
    {:noreply,
     socket |> assign(:form, to_form(params, as: :project)) |> assign(:error_message, nil)}
  end

  @impl true
  def handle_event("save", %{"project" => params}, socket) do
    with {:ok, name} <- validate_name(params["name"]),
         {:ok, repo_ref} <- RepoRef.parse(params["repository"] || ""),
         {:ok, installation_id} <- validate_installation(socket.assigns.installation_id),
         {:ok, project} <- create_project(name),
         {:ok, connection} <- create_connection(project.id, repo_ref, installation_id),
         {:ok, _version} <- RepoImporter.import_new_version(project, connection) do
      {:noreply,
       socket
       |> put_flash(:info, "Project imported from GitHub successfully")
       |> push_navigate(to: ~p"/projects/#{project.id}")}
    else
      {:error, reason} ->
        {:noreply, assign(socket, :error_message, reason)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <.header>
          Create Project from GitHub
          <:subtitle>
            Connect your GitHub App installation, then import `mix.lock` + `mix.exs`.
          </:subtitle>
          <:actions>
            <a
              href={~p"/github/connect?return_to=/projects/new"}
              class="btn btn-secondary"
              id="connect-github-btn"
            >
              Connect GitHub App
            </a>
          </:actions>
        </.header>

        <div class="card bg-base-200 border border-base-300 p-4" id="github-installation-status">
          <%= if @installation_id do %>
            <p class="text-sm">GitHub installation connected: <strong>{@installation_id}</strong></p>
          <% else %>
            <%= if @github_install_configured? do %>
              <p class="text-sm text-error">
                No GitHub installation connected yet. Click "Connect GitHub App" first.
              </p>
            <% else %>
              <p class="text-sm text-error">
                GitHub App install URL is not configured. Set `GITHUB_APP_INSTALL_URL` and retry.
              </p>
            <% end %>
          <% end %>
        </div>

        <.form for={@form} id="project-form" phx-change="validate" phx-submit="save" class="space-y-4">
          <.input field={@form[:name]} type="text" label="Project Name" required />
          <.input
            field={@form[:repository]}
            type="text"
            label="Repository (owner/repo or GitHub URL)"
            placeholder="elixir-lang/elixir"
            required
          />

          <div :if={@error_message} class="alert alert-error" id="project-form-error">
            <span>{@error_message}</span>
          </div>

          <div class="flex gap-3">
            <button type="submit" class="btn btn-primary" id="project-submit-btn">
              Create + Import
            </button>
            <a href={~p"/dashboard"} class="btn btn-outline" id="project-cancel-btn">Cancel</a>
          </div>
        </.form>
      </section>
    </Layouts.app>
    """
  end

  defp validate_name(value) do
    name = value |> to_string() |> String.trim()

    if name == "" do
      {:error, "Project name is required"}
    else
      {:ok, name}
    end
  end

  defp validate_installation(nil), do: {:error, "Please connect a GitHub App installation first"}
  defp validate_installation(id), do: {:ok, id}

  defp create_project(name) do
    Project
    |> Ash.Changeset.for_create(:create, %{name: name, ecosystem: "elixir"})
    |> Ash.create(authorize?: false)
    |> case do
      {:ok, project} -> {:ok, project}
      {:error, _error} -> {:error, "Could not create project"}
    end
  end

  defp create_connection(project_id, repo_ref, installation_id) do
    params = %{
      project_id: project_id,
      provider: "github",
      owner: repo_ref.owner,
      repo: repo_ref.repo,
      installation_id: installation_id,
      sync_status: "pending"
    }

    case RepositoryConnection
         |> Ash.Changeset.for_create(:create, params)
         |> Ash.create(authorize?: false) do
      {:ok, connection} ->
        {:ok, connection}

      {:error, _error} ->
        {:error, "Could not store repository connection"}
    end
  end

  defp parse_installation_id(nil), do: nil
  defp parse_installation_id(id) when is_integer(id), do: id

  defp parse_installation_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, _} -> value
      :error -> nil
    end
  end
end
