defmodule Supabom.TestSupport.GitHubClientMock do
  @behaviour Supabom.Integrations.GitHub.ClientBehaviour

  @impl true
  def fetch_mix_files(_repo_ref) do
    case Application.get_env(:supabom, :github_client_mock_response) do
      nil ->
        {:ok,
         %{
           default_branch: "main",
           mix_lock_path: "mix.lock",
           mix_lock_content:
             "%{\"jason\" => {:hex, :jason, \"1.4.4\", \"hash\", [:mix], [], \"hexpm\", \"outer\"}}",
           mix_exs_path: "mix.exs",
           mix_exs_content: """
           defmodule Demo.MixProject do
             use Mix.Project

             def project do
               [
                 app: :demo,
                 version: "0.1.0",
                 elixir: "~> 1.15"
               ]
             end
           end
           """
         }}

      response ->
        response
    end
  end
end
