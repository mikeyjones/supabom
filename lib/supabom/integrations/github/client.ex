defmodule Supabom.Integrations.GitHub.Client do
  @moduledoc """
  GitHub API client for locating and fetching `mix.lock` and `mix.exs`.
  """

  @behaviour Supabom.Integrations.GitHub.ClientBehaviour

  alias Supabom.Integrations.GitHub.AppAuth

  @github_api "https://api.github.com"

  @impl true
  def fetch_mix_files(%{owner: owner, repo: repo} = repo_ref) do
    with {:ok, headers} <- headers(repo_ref),
         {:ok, default_branch} <- default_branch(owner, repo, headers),
         {:ok, lock_path, mix_path} <- discover_paths(owner, repo, default_branch, headers),
         {:ok, lock_content} <- fetch_content(owner, repo, lock_path, default_branch, headers),
         {:ok, mix_content} <- fetch_content(owner, repo, mix_path, default_branch, headers) do
      {:ok,
       %{
         default_branch: default_branch,
         mix_lock_path: lock_path,
         mix_lock_content: lock_content,
         mix_exs_path: mix_path,
         mix_exs_content: mix_content
       }}
    end
  end

  def fetch_mix_files(_), do: {:error, "Missing repository owner or name"}

  defp headers(%{installation_id: installation_id}) when is_integer(installation_id) do
    with {:ok, token} <- AppAuth.installation_token(installation_id) do
      {:ok, common_headers() ++ [{"authorization", "Bearer #{token}"}]}
    end
  end

  defp headers(%{installation_id: installation_id}) when is_binary(installation_id) do
    case Integer.parse(installation_id) do
      {id, _} -> headers(%{installation_id: id})
      :error -> {:error, "GitHub installation id is invalid"}
    end
  end

  defp headers(_), do: {:ok, common_headers()}

  defp common_headers do
    [
      {"accept", "application/vnd.github+json"},
      {"x-github-api-version", "2022-11-28"}
    ]
  end

  defp default_branch(owner, repo, headers) do
    case Req.get(url: "#{@github_api}/repos/#{owner}/#{repo}", headers: headers) do
      {:ok, %Req.Response{status: status, body: %{"default_branch" => branch}}}
      when status in 200..299 and is_binary(branch) ->
        {:ok, branch}

      {:ok, %Req.Response{status: 404}} ->
        {:error, "Repository not found or not accessible"}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Failed to read repository metadata (status #{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "GitHub request failed: #{inspect(reason)}"}
    end
  end

  defp discover_paths(owner, repo, branch, headers) do
    with {:ok, root_lock} <- existing_path(owner, repo, "mix.lock", branch, headers),
         {:ok, root_mix} <- existing_path(owner, repo, "mix.exs", branch, headers) do
      case {root_lock, root_mix} do
        {"mix.lock", "mix.exs"} ->
          {:ok, "mix.lock", "mix.exs"}

        _ ->
          discover_paths_from_tree(owner, repo, branch, headers, root_lock, root_mix)
      end
    end
  end

  defp discover_paths_from_tree(owner, repo, branch, headers, lock_path, mix_path) do
    with {:ok, tree_paths} <- list_tree_paths(owner, repo, branch, headers),
         resolved_lock <- lock_path || Enum.find(tree_paths, &String.ends_with?(&1, "/mix.lock")),
         resolved_mix <- mix_path || Enum.find(tree_paths, &String.ends_with?(&1, "/mix.exs")) do
      cond do
        is_nil(resolved_lock) -> {:error, "Could not find mix.lock in repository"}
        is_nil(resolved_mix) -> {:error, "Could not find mix.exs in repository"}
        true -> {:ok, resolved_lock, resolved_mix}
      end
    end
  end

  defp list_tree_paths(owner, repo, branch, headers) do
    case Req.get(
           url: "#{@github_api}/repos/#{owner}/#{repo}/git/trees/#{branch}?recursive=1",
           headers: headers
         ) do
      {:ok, %Req.Response{status: status, body: %{"tree" => entries}}} when status in 200..299 ->
        paths =
          entries
          |> Enum.filter(&(&1["type"] == "blob"))
          |> Enum.map(& &1["path"])
          |> Enum.sort_by(fn path -> {String.split(path, "/") |> length(), path} end)

        {:ok, paths}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Failed to list repository files (status #{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "GitHub request failed: #{inspect(reason)}"}
    end
  end

  defp existing_path(owner, repo, path, branch, headers) do
    case Req.get(
           url: "#{@github_api}/repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch}",
           headers: headers
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, path}

      {:ok, %Req.Response{status: 404}} ->
        {:ok, nil}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "GitHub error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "GitHub request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_content(owner, repo, path, branch, headers) do
    case Req.get(
           url: "#{@github_api}/repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch}",
           headers: headers
         ) do
      {:ok, %Req.Response{status: status, body: %{"content" => content, "encoding" => "base64"}}}
      when status in 200..299 ->
        decode_base64(content)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Failed to fetch #{path} (status #{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "GitHub request failed: #{inspect(reason)}"}
    end
  end

  defp decode_base64(content) do
    cleaned = content |> String.replace("\n", "") |> String.trim()

    case Base.decode64(cleaned) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, "GitHub returned invalid base64 content"}
    end
  end
end
