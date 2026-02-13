defmodule Supabom.Projects.MixExsParser do
  @moduledoc """
  Parses `mix.exs` files to extract project metadata using AST navigation.

  Unlike mix.lock files which contain literal data, mix.exs files contain
  executable code, so we use AST navigation instead of evaluation for safety.
  """

  @type metadata :: %{
          project_version: String.t() | nil,
          elixir_version: String.t() | nil
        }

  @spec parse_file(Path.t()) :: {:ok, metadata()} | {:error, String.t()}
  def parse_file(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> parse_content(content)
      {:error, reason} -> {:error, "Could not read uploaded file: #{:file.format_error(reason)}"}
    end
  end

  @spec parse_content(String.t()) :: {:ok, metadata()} | {:error, String.t()}
  def parse_content(content) when is_binary(content) do
    with {:ok, ast} <- quoted(content),
         {:ok, project_keyword_list} <- extract_project_function(ast) do
      metadata = %{
        project_version: extract_value(project_keyword_list, :version),
        elixir_version: extract_value(project_keyword_list, :elixir)
      }

      {:ok, metadata}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp quoted(content) do
    case Code.string_to_quoted(content) do
      {:ok, ast} ->
        {:ok, ast}

      {:error, {metadata, error_msg, _token}} when is_list(metadata) ->
        line = Keyword.get(metadata, :line, "unknown")
        {:error, "mix.exs parse error on line #{line}: #{error_msg}"}

      {:error, other} ->
        {:error, "mix.exs parse error: #{inspect(other)}"}
    end
  end

  # Extract the project/0 function from the AST
  defp extract_project_function(ast) do
    result =
      Macro.prewalk(ast, nil, fn
        # Match: def project do ... end
        {:def, _meta, [{:project, _fn_meta, nil}, [do: body]]} = node, _acc ->
          {node, {:found, body}}

        node, acc ->
          {node, acc}
      end)

    case result do
      {_ast, {:found, body}} ->
        extract_keyword_list(body)

      {_ast, nil} ->
        {:error, "Could not find project/0 function in mix.exs"}
    end
  end

  # Extract a keyword list from the function body
  defp extract_keyword_list(body) do
    case body do
      # Direct keyword list: [key: value, ...]
      list when is_list(list) ->
        {:ok, list}

      # Block with a keyword list: do [key: value, ...] end
      {:__block__, _meta, [list]} when is_list(list) ->
        {:ok, list}

      _ ->
        {:error, "Could not extract keyword list from project/0 function"}
    end
  end

  # Extract a literal value from a keyword list
  defp extract_value(keyword_list, key) do
    case Keyword.get(keyword_list, key) do
      nil ->
        nil

      # String literal
      value when is_binary(value) ->
        value

      # Atom literal (convert to string)
      value when is_atom(value) ->
        to_string(value)

      # Number literal (convert to string)
      value when is_number(value) ->
        to_string(value)

      # Any other literal value, try converting to string
      value ->
        try do
          to_string(value)
        rescue
          _ -> nil
        end
    end
  end
end
