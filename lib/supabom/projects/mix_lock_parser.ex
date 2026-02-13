defmodule Supabom.Projects.MixLockParser do
  @moduledoc """
  Parses `mix.lock` files into normalized dependency entries.
  """

  @type dependency :: %{package: String.t(), version: String.t(), manager: String.t()}

  @spec parse_file(Path.t()) :: {:ok, [dependency()]} | {:error, String.t()}
  def parse_file(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> parse_content(content)
      {:error, reason} -> {:error, "Could not read uploaded file: #{:file.format_error(reason)}"}
    end
  end

  @spec parse_content(String.t()) :: {:ok, [dependency()]} | {:error, String.t()}
  def parse_content(content) when is_binary(content) do
    with {:ok, ast} <- quoted(content),
         :ok <- ensure_literal(ast),
         {lock_map, _binding} <- Code.eval_quoted(ast, [], __ENV__),
         true <- is_map(lock_map) do
      dependencies =
        lock_map
        |> Enum.map(fn {package, lock_entry} ->
          parse_dependency(package, lock_entry)
        end)
        |> Enum.sort_by(fn %{package: package, manager: manager} -> {package, manager} end)

      {:ok, dependencies}
    else
      false ->
        {:error, "Uploaded file does not contain a valid mix.lock map"}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Unable to parse uploaded mix.lock file"}
    end
  end

  defp quoted(content) do
    case Code.string_to_quoted(content) do
      {:ok, ast} ->
        {:ok, ast}

      {:error, {line, error, token}} ->
        {:error, "mix.lock parse error on line #{line}: #{error} #{token}"}
    end
  end

  defp ensure_literal(ast) do
    if Macro.quoted_literal?(ast) do
      :ok
    else
      {:error, "mix.lock contains unsupported syntax; expected a literal map"}
    end
  end

  defp parse_dependency(
         package_name,
         {:hex, _name, version, _hash, _build_tools, _deps, _repo, _}
       ) do
    %{package: to_string(package_name), version: to_string(version), manager: "hex"}
  end

  defp parse_dependency(package_name, {:hex, _name, version, _hash, _build_tools, _deps, _repo}) do
    %{package: to_string(package_name), version: to_string(version), manager: "hex"}
  end

  defp parse_dependency(package_name, {:git, _url, ref, _opts}) do
    %{package: to_string(package_name), version: to_string(ref || "git"), manager: "git"}
  end

  defp parse_dependency(package_name, _other) do
    %{package: to_string(package_name), version: "unknown", manager: "other"}
  end
end
