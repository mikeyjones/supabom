defmodule Supabom.Projects.RepoImporter do
  @moduledoc """
  Imports project metadata and dependencies from a connected GitHub repository.
  """

  require Ash.Query

  alias Supabom.Projects.Dependency
  alias Supabom.Projects.MixExsParser
  alias Supabom.Projects.MixLockParser
  alias Supabom.Projects.Project
  alias Supabom.Projects.ProjectVersion
  alias Supabom.Projects.RepositoryConnection

  @spec import_new_version(Project.t(), RepositoryConnection.t()) ::
          {:ok, ProjectVersion.t()} | {:error, String.t()}
  def import_new_version(project, repository_connection) do
    with {:ok, fetched} <- github_client().fetch_mix_files(repo_ref(repository_connection)),
         {:ok, dependencies} <- MixLockParser.parse_content(fetched.mix_lock_content),
         {:ok, metadata} <- MixExsParser.parse_content(fetched.mix_exs_content),
         {:ok, project_version} <- create_project_version(project, metadata),
         :ok <- create_dependencies(project.id, project_version.id, dependencies),
         :ok <- update_project_snapshot(project, metadata),
         :ok <- mark_sync_success(repository_connection, fetched.default_branch) do
      {:ok, Ash.load!(project_version, :dependencies, authorize?: false)}
    else
      {:error, reason} = error ->
        _ = mark_sync_error(repository_connection, reason)
        error
    end
  end

  defp create_project_version(project, metadata) do
    create_project_version_with_retry(project.id, metadata, 3)
  end

  defp create_project_version_with_retry(_project_id, _metadata, 0) do
    {:error, "Could not allocate a version number. Please try again."}
  end

  defp create_project_version_with_retry(project_id, metadata, attempts_left) do
    attrs = %{
      project_id: project_id,
      version_number: next_version_number(project_id),
      project_version: metadata.project_version,
      elixir_version: metadata.elixir_version
    }

    case ProjectVersion
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create(authorize?: false) do
      {:ok, version} ->
        {:ok, version}

      {:error, error} ->
        if inspect(error) =~ "project_versions_project_id_version_number_index" do
          create_project_version_with_retry(project_id, metadata, attempts_left - 1)
        else
          {:error, "Failed to create version: #{inspect(error)}"}
        end
    end
  end

  defp next_version_number(project_id) do
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

  defp create_dependencies(project_id, version_id, dependencies) do
    result =
      Enum.reduce_while(dependencies, :ok, fn dependency, :ok ->
        params = %{
          project_id: project_id,
          project_version_id: version_id,
          package: dependency.package,
          version: dependency.version,
          manager: dependency.manager
        }

        case Dependency
             |> Ash.Changeset.for_create(:create, params)
             |> Ash.create(authorize?: false) do
          {:ok, _saved} -> {:cont, :ok}
          {:error, _error} -> {:halt, :error}
        end
      end)

    case result do
      :ok -> :ok
      :error -> {:error, "Failed to create dependencies"}
    end
  end

  defp update_project_snapshot(project, metadata) do
    attrs = %{
      project_version: metadata.project_version,
      elixir_version: metadata.elixir_version
    }

    case project
         |> Ash.Changeset.for_update(:update, attrs)
         |> Ash.update(authorize?: false) do
      {:ok, _project} -> :ok
      {:error, _error} -> {:error, "Failed to update project metadata"}
    end
  end

  defp mark_sync_success(repository_connection, default_branch) do
    attrs = %{
      default_branch: default_branch,
      sync_status: "ok",
      sync_error: nil,
      last_synced_at: DateTime.utc_now()
    }

    case repository_connection
         |> Ash.Changeset.for_update(:update, attrs)
         |> Ash.update(authorize?: false) do
      {:ok, _connection} -> :ok
      {:error, _error} -> :ok
    end
  end

  defp mark_sync_error(repository_connection, reason) do
    attrs = %{
      sync_status: "error",
      sync_error: reason
    }

    case repository_connection
         |> Ash.Changeset.for_update(:update, attrs)
         |> Ash.update(authorize?: false) do
      {:ok, _connection} -> :ok
      {:error, _error} -> :ok
    end
  end

  defp repo_ref(connection) do
    %{
      owner: connection.owner,
      repo: connection.repo,
      installation_id: connection.installation_id
    }
  end

  defp github_client do
    Application.get_env(:supabom, :github_client, Supabom.Integrations.GitHub.Client)
  end
end
