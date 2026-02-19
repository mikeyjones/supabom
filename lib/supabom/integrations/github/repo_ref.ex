defmodule Supabom.Integrations.GitHub.RepoRef do
  @moduledoc """
  Helpers for parsing owner/repo references.
  """

  @spec parse(String.t()) :: {:ok, %{owner: String.t(), repo: String.t()}} | {:error, String.t()}
  def parse(value) when is_binary(value) do
    cleaned =
      value
      |> String.trim()
      |> String.trim_leading("https://github.com/")
      |> String.trim_leading("http://github.com/")
      |> String.trim_leading("github.com/")
      |> String.trim_trailing(".git")
      |> String.trim("/")

    case String.split(cleaned, "/", parts: 3) do
      [owner, repo] when owner != "" and repo != "" ->
        {:ok, %{owner: owner, repo: repo}}

      _ ->
        {:error, "Repository must be in the format owner/repo"}
    end
  end

  def parse(_), do: {:error, "Repository must be in the format owner/repo"}
end
