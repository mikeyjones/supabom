defmodule SupabomWeb.ProjectNewLive do
  use SupabomWeb, :live_view

  alias Supabom.Projects.Dependency
  alias Supabom.Projects.MixExsParser
  alias Supabom.Projects.MixLockParser
  alias Supabom.Projects.Project

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Create Project")
      |> assign(:current_scope, nil)
      |> assign(:form, to_form(%{"name" => ""}, as: :project))
      |> assign(:error_message, nil)
      |> allow_upload(:lockfile, accept: :any, max_entries: 1)
      |> allow_upload(:mixexs, accept: :any, max_entries: 1)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"project" => params}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :project))
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_event("save", %{"project" => params} = all_params, socket) do
    require Logger
    Logger.debug("Save event params: #{inspect(all_params)}")
    Logger.debug("Upload entries: #{inspect(socket.assigns.uploads.lockfile.entries)}")

    raw_name = Map.get(params, "name", "")
    name = String.trim(raw_name)

    cond do
      name == "" ->
        Logger.debug("Validation failed: name is empty")
        {:noreply, assign(socket, :error_message, "Project name is required")}

      socket.assigns.uploads.lockfile.entries == [] ->
        Logger.debug("Validation failed: no lockfile uploaded")
        {:noreply, assign(socket, :error_message, "Please upload a mix.lock file")}

      not valid_mix_lock_filename?(socket.assigns.uploads.lockfile.entries) ->
        Logger.debug("Validation failed: invalid lockfile filename")
        {:noreply, assign(socket, :error_message, "Please upload a file named mix.lock")}

      socket.assigns.uploads.mixexs.entries == [] ->
        Logger.debug("Validation failed: no mix.exs uploaded")
        {:noreply, assign(socket, :error_message, "Please upload a mix.exs file")}

      not valid_mix_exs_filename?(socket.assigns.uploads.mixexs.entries) ->
        Logger.debug("Validation failed: invalid mix.exs filename")
        {:noreply, assign(socket, :error_message, "Please upload a file named mix.exs")}

      true ->
        Logger.debug("Validation passed, saving project")
        save_project(socket, name)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <style>
        .project-form-container {
          background: var(--dark-surface);
          padding: 40px;
          border-radius: 35px;
          border: 4px solid var(--purple);
          transform: rotate(-0.5deg);
          transition: all 0.4s cubic-bezier(0.68, -0.55, 0.265, 1.55);
          box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
          margin-top: 20px;
        }

        .project-form-container:hover {
          transform: rotate(0deg);
          box-shadow: 0 20px 60px rgba(151, 117, 250, 0.3);
          border-color: var(--purple-bright);
        }

        .form-group {
          margin-bottom: 25px;
        }

        .form-group label {
          display: block;
          font-size: 16px;
          font-weight: 600;
          color: var(--text);
          margin-bottom: 10px;
        }

        .form-group input[type="text"],
        .form-group input[type="email"],
        .form-group input[type="password"],
        .form-group textarea,
        .form-group select {
          width: 100%;
          padding: 15px 20px;
          background: var(--dark-elevated);
          border: 3px solid var(--mint);
          border-radius: 20px;
          color: var(--text);
          font-family: 'Fredoka', sans-serif;
          font-size: 16px;
          font-weight: 500;
          transition: all 0.3s ease;
        }

        .form-group input:focus,
        .form-group textarea:focus,
        .form-group select:focus {
          outline: none;
          border-color: var(--mint-bright);
          box-shadow: 0 0 20px rgba(81, 207, 102, 0.4);
          transform: scale(1.02);
        }

        .form-help {
          font-size: 14px;
          color: var(--text-dim);
          margin-top: 8px;
          font-weight: 500;
        }

        .btn-primary {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 18px 40px;
          font-family: 'Fredoka', sans-serif;
          font-size: 18px;
          font-weight: 700;
          border-radius: 30px;
          text-decoration: none;
          transition: all 0.4s cubic-bezier(0.68, -0.55, 0.265, 1.55);
          border: 4px solid transparent;
          cursor: pointer;
          background: var(--mint);
          color: var(--dark-bg);
          box-shadow: 0 0 30px rgba(81, 207, 102, 0.5);
          border-color: var(--mint-bright);
          transform: rotate(-1deg);
        }

        .btn-primary:hover {
          background: var(--mint-bright);
          transform: rotate(1deg) scale(1.05) translateY(-3px);
          box-shadow: 0 0 50px rgba(81, 207, 102, 0.8);
        }

        .btn-secondary {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 18px 40px;
          font-family: 'Fredoka', sans-serif;
          font-size: 18px;
          font-weight: 700;
          border-radius: 30px;
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
          box-shadow: 0 0 30px rgba(151, 117, 250, 0.5);
        }

        .error-alert {
          background: rgba(255, 107, 107, 0.2);
          border: 3px solid var(--coral);
          border-radius: 20px;
          padding: 15px 20px;
          color: var(--coral-bright);
          font-weight: 600;
          margin-bottom: 20px;
        }

        .button-group {
          display: flex;
          gap: 15px;
          margin-top: 30px;
        }
      </style>

      <h1 class="page-title">Create Your First Project 🚀</h1>
      <p class="page-subtitle">
        Upload your mix.lock and mix.exs files to track dependencies and versions
      </p>

      <div class="project-form-container">
        <.form for={@form} id="project-form" phx-change="validate" phx-submit="save">
          <div class="form-group">
            <.input
              field={@form[:name]}
              type="text"
              label="Project Name"
              placeholder="My Awesome Project"
              required
            />
          </div>

          <div class="form-group">
            <label class="form-label" for="project-lockfile">mix.lock File</label>
            <.live_file_input upload={@uploads.lockfile} id="project-lockfile" />
            <p class="form-help">
              Upload your mix.lock file for dependency information.
            </p>
          </div>

          <div class="form-group">
            <label class="form-label" for="project-mixexs">mix.exs File</label>
            <.live_file_input upload={@uploads.mixexs} id="project-mixexs" />
            <p class="form-help">
              Upload your mix.exs file for version information.
            </p>
          </div>

          <div :if={@error_message} class="error-alert" id="project-form-error">
            {@error_message}
          </div>

          <div class="button-group">
            <button type="submit" class="btn-primary" id="project-submit-btn">
              Create Project ✨
            </button>
            <a href={~p"/dashboard"} class="btn-secondary" id="project-cancel-btn">Cancel</a>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  defp save_project(socket, name) do
    # Parse mix.lock for dependencies
    lockfile_results =
      consume_uploaded_entries(socket, :lockfile, fn %{path: path}, _entry ->
        {:ok, MixLockParser.parse_file(path)}
      end)

    # Parse mix.exs for version metadata
    mixexs_results =
      consume_uploaded_entries(socket, :mixexs, fn %{path: path}, _entry ->
        {:ok, MixExsParser.parse_file(path)}
      end)

    with {:ok, dependencies} <- extract_dependencies(lockfile_results),
         {:ok, metadata} <- extract_metadata(mixexs_results),
         {:ok, project} <- create_project(name, metadata),
         :ok <- create_dependencies(project.id, dependencies) do
      {:noreply,
       socket
       |> put_flash(:info, "Project created successfully")
       |> push_navigate(to: ~p"/projects/#{project.id}")}
    else
      {:error, message} ->
        {:noreply, assign(socket, :error_message, message)}
    end
  end

  defp extract_dependencies(ok: dependencies) when is_list(dependencies),
    do: {:ok, dependencies}

  defp extract_dependencies(ok: {:ok, dependencies}) when is_list(dependencies),
    do: {:ok, dependencies}

  defp extract_dependencies([{:error, reason}]), do: {:error, reason}
  defp extract_dependencies(ok: {:error, reason}), do: {:error, reason}
  defp extract_dependencies(_), do: {:error, "Could not process uploaded mix.lock file"}

  defp extract_metadata(ok: {:ok, metadata}), do: {:ok, metadata}
  defp extract_metadata(ok: metadata) when is_map(metadata), do: {:ok, metadata}

  defp extract_metadata(ok: {:error, reason}), do: {:error, reason}

  defp extract_metadata(other) do
    require Logger
    Logger.error("Unexpected metadata extraction result: #{inspect(other)}")
    {:error, "Could not process mix.exs file"}
  end

  defp valid_mix_lock_filename?([entry]), do: entry.client_name == "mix.lock"
  defp valid_mix_lock_filename?(_), do: false

  defp valid_mix_exs_filename?([entry]), do: entry.client_name == "mix.exs"
  defp valid_mix_exs_filename?(_), do: false

  defp create_project(name, metadata) do
    params =
      Map.merge(
        %{name: name, ecosystem: "elixir"},
        metadata
      )

    Project
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create(authorize?: false)
    |> case do
      {:ok, project} -> {:ok, project}
      {:error, _error} -> {:error, "Could not create project"}
    end
  end

  defp create_dependencies(project_id, dependencies) do
    result =
      Enum.reduce_while(dependencies, :ok, fn dependency, :ok ->
        params = %{
          project_id: project_id,
          package: dependency.package,
          version: dependency.version,
          manager: dependency.manager
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
      :ok -> :ok
      :error -> {:error, "Could not save parsed dependencies"}
    end
  end
end
