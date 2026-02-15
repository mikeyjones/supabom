defmodule SupabomWeb.ProjectShowLive do
  use SupabomWeb, :live_view
  require Ash.Query

  alias Supabom.Projects.Dependency
  alias Supabom.Projects.MixExsParser
  alias Supabom.Projects.MixLockParser
  alias Supabom.Projects.Project
  alias Supabom.Projects.ProjectVersion

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
    case Ash.get(Project, id, load: [:dependencies, :versions], authorize?: false) do
      {:ok, nil} ->
        {:ok,
         socket
         |> put_flash(:error, "Project not found")
         |> push_navigate(to: ~p"/dashboard")}

      {:ok, project} ->
        current_version = get_current_version(project)

        dependencies =
          if current_version do
            Enum.sort_by(current_version.dependencies, fn dependency ->
              {dependency.package, dependency.version}
            end)
          else
            project.dependencies
            |> Enum.sort_by(fn dependency -> {dependency.package, dependency.version} end)
          end

        socket =
          socket
          |> assign(:page_title, project.name)
          |> assign(:current_scope, nil)
          |> assign(:project, project)
          |> assign(:current_version, current_version)
          |> assign(:dependencies, dependencies)
          |> assign(:dependencies_collapsed, true)
          |> assign(:show_upload_modal, false)
          |> assign(:uploaded_files, [])
          |> allow_upload(:lockfile, accept: :any, max_entries: 1)
          |> allow_upload(:mixexs, accept: :any, max_entries: 1)

        {:ok, socket}

      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, "Could not load project")
         |> push_navigate(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("toggle_dependencies", _params, socket) do
    {:noreply, assign(socket, :dependencies_collapsed, !socket.assigns.dependencies_collapsed)}
  end

  @impl true
  def handle_event("open_upload_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_upload_modal, true)
      |> allow_upload(:lockfile, accept: :any, max_entries: 1)
      |> allow_upload(:mixexs, accept: :any, max_entries: 1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_upload_modal, false)}
  end

  @impl true
  def handle_event("prevent_close", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_version", _params, socket) do
    require Logger

    Logger.debug(
      "Upload version event - lockfile entries: #{inspect(socket.assigns.uploads.lockfile.entries)}"
    )

    Logger.debug(
      "Upload version event - lockfile errors: #{inspect(socket.assigns.uploads.lockfile.errors)}"
    )

    Logger.debug(
      "Upload version event - mixexs entries: #{inspect(socket.assigns.uploads.mixexs.entries)}"
    )

    Logger.debug(
      "Upload version event - mixexs errors: #{inspect(socket.assigns.uploads.mixexs.errors)}"
    )

    Logger.debug("Upload config - lockfile: #{inspect(socket.assigns.uploads.lockfile)}")

    # Validate that files were uploaded
    cond do
      socket.assigns.uploads.lockfile.entries == [] ->
        {:noreply, put_flash(socket, :error, "Please select a mix.lock file to upload")}

      socket.assigns.uploads.mixexs.entries == [] ->
        {:noreply, put_flash(socket, :error, "Please select a mix.exs file to upload")}

      true ->
        with {:ok, dependencies, metadata} <- process_uploads(socket),
             {:ok, version} <-
               create_new_version(socket.assigns.project, dependencies, metadata) do
          dependencies = Enum.sort_by(version.dependencies, &{&1.package, &1.version})

          version_label =
            if version.project_version do
              "Version #{version.project_version}"
            else
              "Version ##{version.version_number}"
            end

          socket =
            socket
            |> put_flash(:info, "#{version_label} uploaded successfully!")
            |> assign(:show_upload_modal, false)
            |> assign(:current_version, version)
            |> assign(:dependencies, dependencies)

          {:noreply, socket}
        else
          {:error, message} ->
            {:noreply, put_flash(socket, :error, message)}
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

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not load version")}
    end
  end

  defp get_current_version(project) do
    case project.versions do
      [version | _] -> Ash.load!(version, :dependencies)
      [] -> nil
    end
  end

  defp process_uploads(socket) do
    with {:ok, dependencies} <- parse_lockfile(socket),
         {:ok, metadata} <- parse_mixexs(socket) do
      {:ok, dependencies, metadata}
    end
  end

  defp parse_lockfile(socket) do
    results =
      consume_uploaded_entries(socket, :lockfile, fn %{path: path}, _entry ->
        {:ok, MixLockParser.parse_file(path)}
      end)

    case results do
      [result] -> extract_lockfile_result(result)
      [] -> {:error, "No lockfile was uploaded"}
      _ -> {:error, "Failed to process lockfile"}
    end
  end

  defp extract_lockfile_result({:ok, dependencies}) when is_list(dependencies),
    do: {:ok, dependencies}

  defp extract_lockfile_result({:ok, {:ok, dependencies}}) when is_list(dependencies),
    do: {:ok, dependencies}

  defp extract_lockfile_result({:ok, {:error, reason}}), do: {:error, reason}
  defp extract_lockfile_result({:error, reason}), do: {:error, reason}
  defp extract_lockfile_result(_), do: {:error, "Could not process uploaded mix.lock file"}

  defp parse_mixexs(socket) do
    results =
      consume_uploaded_entries(socket, :mixexs, fn %{path: path}, _entry ->
        {:ok, MixExsParser.parse_file(path)}
      end)

    case results do
      [result] -> extract_mixexs_result(result)
      [] -> {:error, "No mix.exs file was uploaded"}
      _ -> {:error, "Failed to process mix.exs"}
    end
  end

  defp extract_mixexs_result({:ok, metadata}) when is_map(metadata), do: {:ok, metadata}
  defp extract_mixexs_result({:ok, {:ok, metadata}}) when is_map(metadata), do: {:ok, metadata}
  defp extract_mixexs_result({:ok, {:error, reason}}), do: {:error, reason}
  defp extract_mixexs_result({:error, reason}), do: {:error, reason}
  defp extract_mixexs_result(_), do: {:error, "Could not process mix.exs file"}

  defp create_new_version(project, dependencies, metadata) do
    case create_project_version_with_retry(project, metadata, 3) do
      {:ok, version} ->
        result =
          Enum.reduce_while(dependencies, :ok, fn dep, :ok ->
            params = %{
              project_version_id: version.id,
              project_id: project.id,
              package: dep.package,
              version: dep.version,
              manager: dep.manager
            }

            case Dependency
                 |> Ash.Changeset.for_create(:create, params)
                 |> Ash.create(authorize?: false) do
              {:ok, _saved} ->
                {:cont, :ok}

              {:error, _error} ->
                {:halt, :error}
            end
          end)

        case result do
          :ok -> {:ok, Ash.load!(version, :dependencies)}
          :error -> {:error, "Failed to create dependencies"}
        end

      {:error, error} ->
        {:error, "Failed to create version: #{inspect(error)}"}
    end
  end

  defp create_project_version_with_retry(_project, _metadata, 0) do
    {:error, "Version number conflict. Please try again."}
  end

  defp create_project_version_with_retry(project, metadata, attempts_left) do
    version_attrs = %{
      project_id: project.id,
      version_number: get_next_version_number(project.id),
      project_version: metadata.project_version,
      elixir_version: metadata.elixir_version
    }

    case ProjectVersion
         |> Ash.Changeset.for_create(:create, version_attrs)
         |> Ash.create(authorize?: false) do
      {:ok, version} ->
        {:ok, version}

      {:error, error} ->
        if version_number_conflict?(error) do
          create_project_version_with_retry(project, metadata, attempts_left - 1)
        else
          {:error, error}
        end
    end
  end

  defp get_next_version_number(project_id) do
    query =
      ProjectVersion
      |> Ash.Query.filter(project_id == ^project_id)

    case Ash.read(query, authorize?: false) do
      {:ok, []} ->
        1

      {:ok, versions} ->
        versions
        |> Enum.map(& &1.version_number)
        |> Enum.max()
        |> Kernel.+(1)

      _ ->
        1
    end
  end

  defp version_number_conflict?(error) do
    inspect(error) =~ "project_versions_project_id_version_number_index"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <style>
        :root {
          --mint: #51cf66;
          --mint-bright: #63e777;
          --purple: #9775fa;
          --purple-bright: #a78bfa;
          --coral: #ff6b6b;
          --dark-bg: #1a1625;
          --dark-surface: #251e35;
          --dark-elevated: #2d2540;
          --text: #f5f3ff;
          --text-dim: #b4a7d6;
        }

        .btn-primary {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 12px 30px;
          font-family: 'Fredoka', sans-serif;
          font-size: 16px;
          font-weight: 700;
          border-radius: 25px;
          text-decoration: none;
          transition: all 0.4s cubic-bezier(0.68, -0.55, 0.265, 1.55);
          border: 4px solid transparent;
          cursor: pointer;
          background: var(--mint);
          color: var(--dark-bg);
          box-shadow: 0 0 25px rgba(81, 207, 102, 0.4);
          border-color: var(--mint-bright);
          transform: rotate(-1deg);
        }

        .btn-primary:hover {
          background: var(--mint-bright);
          transform: rotate(1deg) scale(1.05) translateY(-3px);
          box-shadow: 0 0 40px rgba(81, 207, 102, 0.7);
        }

        .btn-secondary {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 12px 30px;
          font-family: 'Fredoka', sans-serif;
          font-size: 16px;
          font-weight: 700;
          border-radius: 25px;
          text-decoration: none;
          transition: all 0.4s cubic-bezier(0.68, -0.55, 0.265, 1.55);
          border: 4px solid var(--purple);
          cursor: pointer;
          background: transparent;
          color: var(--text);
          transform: rotate(0.5deg);
        }

        .btn-secondary:hover {
          background: var(--purple);
          transform: rotate(-0.5deg) scale(1.05) translateY(-3px);
          box-shadow: 0 0 25px rgba(151, 117, 250, 0.4);
        }

        .button-group {
          display: flex;
          gap: 15px;
          flex-wrap: wrap;
        }

        .dependency-summary-card {
          background: var(--dark-surface);
          padding: 30px;
          border-radius: 30px;
          border: 4px solid var(--purple);
          margin-bottom: 25px;
          cursor: pointer;
          transition: all 0.3s ease;
          transform: rotate(-0.3deg);
        }

        .dependency-summary-card:hover {
          transform: rotate(0deg) translateY(-3px);
          box-shadow: 0 15px 40px rgba(151, 117, 250, 0.2);
          border-color: var(--purple-bright);
        }

        .summary-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 20px;
        }

        .summary-title {
          font-size: 24px;
          font-weight: 700;
          color: var(--text);
          margin-bottom: 8px;
        }

        .summary-count {
          font-size: 16px;
          color: var(--text-dim);
          font-weight: 500;
        }

        .toggle-btn {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 10px 20px;
          background: var(--mint);
          color: var(--dark-bg);
          border: none;
          border-radius: 20px;
          font-family: 'Fredoka', sans-serif;
          font-size: 15px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s ease;
        }

        .toggle-btn:hover {
          background: var(--mint-bright);
          transform: scale(1.05);
        }

        .dependency-table-container {
          overflow-x: auto;
          border-radius: 25px;
          border: 3px solid var(--mint);
          background: var(--dark-surface);
          animation: slideDown 0.3s ease;
        }

        @keyframes slideDown {
          from {
            opacity: 0;
            transform: translateY(-10px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        .dependency-table-container table {
          margin: 0;
        }

        .dependency-table-container th {
          background: var(--dark-elevated);
          font-weight: 700;
          font-size: 14px;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          padding: 18px;
        }

        .dependency-table-container td {
          padding: 15px 18px;
        }

        .dependency-table-container code {
          background: var(--dark-elevated);
          padding: 4px 10px;
          border-radius: 8px;
          font-size: 13px;
          color: var(--mint-bright);
        }

        .empty-dependencies-state {
          text-align: center;
          padding: 60px 40px;
          background: var(--dark-surface);
          border: 4px solid var(--coral);
          border-radius: 30px;
          margin-top: 25px;
        }

        .empty-icon {
          font-size: 60px;
          margin-bottom: 15px;
        }

        .empty-dependencies-state p {
          font-size: 16px;
          color: var(--text-dim);
          font-weight: 500;
        }

        .header-subtitle-content {
          display: flex;
          gap: 12px;
          align-items: center;
          flex-wrap: wrap;
        }

        @media (max-width: 768px) {
          .button-group {
            flex-direction: column;
          }

          .button-group a {
            width: 100%;
          }
        }

        @media (max-width: 640px) {
          .header-subtitle-content {
            flex-direction: column;
            align-items: flex-start;
          }

          .summary-header {
            flex-direction: column;
            align-items: flex-start;
          }

          .toggle-btn {
            align-self: stretch;
            justify-content: center;
          }
        }

        /* Version Info */
        .version-info {
          display: flex;
          align-items: center;
          gap: 15px;
          padding: 20px 25px;
          background: var(--dark-surface);
          border-radius: 20px;
          border: 3px solid var(--mint);
          margin-bottom: 20px;
        }

        .version-badge {
          font-size: 18px;
          font-weight: 700;
          color: var(--mint-bright);
        }

        .upload-date {
          font-size: 14px;
          color: var(--text-dim);
        }

        /* Modal Styles */
        .modal-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0, 0, 0, 0.7);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 1000;
          padding: 20px;
        }

        .modal-content {
          background: var(--dark-surface);
          border-radius: 30px;
          border: 4px solid var(--mint);
          max-width: 600px;
          width: 100%;
          max-height: 90vh;
          overflow-y: auto;
          box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
          animation: modalSlideIn 0.3s ease;
        }

        @keyframes modalSlideIn {
          from {
            opacity: 0;
            transform: translateY(-50px) scale(0.9);
          }
          to {
            opacity: 1;
            transform: translateY(0) scale(1);
          }
        }

        .modal-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 30px 30px 20px;
          border-bottom: 2px solid var(--dark-elevated);
        }

        .modal-header h2 {
          font-size: 28px;
          font-weight: 700;
          color: var(--text);
          margin: 0;
        }

        .modal-close {
          background: transparent;
          border: none;
          color: var(--text-dim);
          cursor: pointer;
          padding: 8px;
          border-radius: 50%;
          transition: all 0.2s ease;
        }

        .modal-close:hover {
          background: var(--dark-elevated);
          color: var(--text);
          transform: rotate(90deg);
        }

        .modal-body {
          padding: 30px;
        }

        .upload-section {
          margin-bottom: 25px;
        }

        .upload-label {
          display: flex;
          align-items: center;
          gap: 8px;
          font-size: 16px;
          font-weight: 600;
          color: var(--text);
          margin-bottom: 12px;
        }

        .upload-dropzone {
          position: relative;
          border: 3px dashed var(--purple);
          border-radius: 20px;
          padding: 40px 20px;
          text-align: center;
          background: var(--dark-elevated);
          transition: all 0.3s ease;
          min-height: 120px;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
        }

        .upload-dropzone:hover {
          border-color: var(--mint);
          background: var(--dark-surface);
        }

        .upload-hint {
          color: var(--text-dim);
          font-size: 14px;
          margin-top: 10px;
          pointer-events: none;
        }

        .upload-entry {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 12px 16px;
          background: var(--dark-elevated);
          border-radius: 15px;
          margin-top: 10px;
          font-size: 14px;
          color: var(--text);
        }

        .text-mint {
          color: var(--mint);
        }

        .modal-actions {
          display: flex;
          gap: 15px;
          margin-top: 30px;
          padding-top: 20px;
          border-top: 2px solid var(--dark-elevated);
        }

        .btn-primary-modal,
        .btn-secondary-modal {
          flex: 1;
          padding: 14px 24px;
          border-radius: 20px;
          font-family: 'Fredoka', sans-serif;
          font-size: 16px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s ease;
          border: none;
        }

        .btn-primary-modal {
          background: var(--mint);
          color: var(--dark-bg);
          border: 3px solid var(--mint-bright);
        }

        .btn-primary-modal:hover {
          background: var(--mint-bright);
          transform: translateY(-2px);
          box-shadow: 0 10px 25px rgba(81, 207, 102, 0.4);
        }

        .btn-secondary-modal {
          background: transparent;
          color: var(--text);
          border: 3px solid var(--purple);
        }

        .btn-secondary-modal:hover {
          background: var(--purple);
          transform: translateY(-2px);
        }
      </style>

      <section class="space-y-6">
        <.header>
          {@project.name}
          <:subtitle>
            <div class="header-subtitle-content">
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
            <div class="button-group">
              <button
                phx-click="open_upload_modal"
                class="btn-primary"
                id="upload-new-lockfile-btn"
              >
                Upload New Version ✨
              </button>
              <a href={~p"/dashboard"} class="btn-secondary" id="back-to-dashboard-btn">
                Back to Dashboard
              </a>
            </div>
          </:actions>
        </.header>

        <%!-- Version info display --%>
        <div :if={@current_version} class="version-info">
          <span class="version-badge">
            <%= if @current_version.project_version do %>
              Version {@current_version.project_version}
            <% else %>
              Version #{@current_version.version_number}
            <% end %>
          </span>
          <span class="upload-date">
            Uploaded {Calendar.strftime(@current_version.uploaded_at, "%B %d, %Y")}
          </span>
        </div>

        <%!-- Upload Modal --%>
        <div
          :if={@show_upload_modal}
          class="modal-overlay"
          phx-click="close_upload_modal"
          id="upload-modal"
        >
          <div class="modal-content" phx-click="prevent_close">
            <div class="modal-header">
              <h2>Upload New Version</h2>
              <button
                phx-click="close_upload_modal"
                class="modal-close"
                aria-label="Close"
                type="button"
              >
                <.icon name="hero-x-mark" class="w-6 h-6" />
              </button>
            </div>

            <div class="modal-body">
              <.form
                for={%{}}
                phx-change="validate_upload"
                phx-submit="upload_version"
                id="version-upload-form"
              >
                <%!-- mix.lock upload --%>
                <div class="upload-section">
                  <label class="upload-label">
                    <.icon name="hero-document-text" class="w-5 h-5" /> mix.lock file
                  </label>
                  <div class="upload-dropzone" phx-drop-target={@uploads.lockfile.ref}>
                    <.live_file_input upload={@uploads.lockfile} id="version-lockfile" />
                    <p class="upload-hint">Click to browse or drag and drop your mix.lock file</p>
                  </div>
                  <%= for entry <- @uploads.lockfile.entries do %>
                    <div class="upload-entry">
                      <.icon name="hero-document-check" class="w-5 h-5 text-mint" />
                      <span>{entry.client_name}</span>
                    </div>
                  <% end %>
                </div>

                <%!-- mix.exs upload --%>
                <div class="upload-section">
                  <label class="upload-label">
                    <.icon name="hero-document-text" class="w-5 h-5" /> mix.exs file
                  </label>
                  <div class="upload-dropzone" phx-drop-target={@uploads.mixexs.ref}>
                    <.live_file_input upload={@uploads.mixexs} id="version-mixexs" />
                    <p class="upload-hint">Click to browse or drag and drop your mix.exs file</p>
                  </div>
                  <%= for entry <- @uploads.mixexs.entries do %>
                    <div class="upload-entry">
                      <.icon name="hero-document-check" class="w-5 h-5 text-mint" />
                      <span>{entry.client_name}</span>
                    </div>
                  <% end %>
                </div>

                <div class="modal-actions">
                  <button
                    type="button"
                    phx-click="close_upload_modal"
                    class="btn-secondary-modal"
                  >
                    Cancel
                  </button>
                  <button type="submit" class="btn-primary-modal">
                    Upload Version
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>

        <div :if={@dependencies == []} class="empty-dependencies-state" id="empty-dependencies-state">
          <div class="empty-icon">📦</div>
          <p>No dependencies were found in the uploaded lockfile.</p>
        </div>

        <%= if @dependencies != [] do %>
          <%!-- Summary card showing dependency count with expand/collapse toggle --%>
          <div class="dependency-summary-card" phx-click="toggle_dependencies">
            <div class="summary-header">
              <div>
                <h3 class="summary-title">Dependencies</h3>
                <p class="summary-count">{length(@dependencies)} packages</p>
              </div>
              <button class="toggle-btn" type="button">
                <%= if @dependencies_collapsed do %>
                  <.icon name="hero-chevron-down" class="w-6 h-6" />
                  <span>Show All</span>
                <% else %>
                  <.icon name="hero-chevron-up" class="w-6 h-6" />
                  <span>Hide</span>
                <% end %>
              </button>
            </div>
          </div>

          <%!-- Dependency table (conditionally rendered) --%>
          <%= if !@dependencies_collapsed do %>
            <div class="dependency-table-container" id="dependencies-container">
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
          <% end %>
        <% end %>
      </section>
    </Layouts.app>
    """
  end
end
