defmodule Supabom.Integrations.GitHub.ClientBehaviour do
  @moduledoc """
  Behaviour for fetching manifests from GitHub repositories.
  """

  @type repo_ref :: %{owner: String.t(), repo: String.t(), installation_id: integer() | nil}

  @type fetch_result :: %{
          default_branch: String.t() | nil,
          mix_lock_path: String.t(),
          mix_lock_content: String.t(),
          mix_exs_path: String.t(),
          mix_exs_content: String.t()
        }

  @callback fetch_mix_files(repo_ref()) :: {:ok, fetch_result()} | {:error, String.t()}
end
