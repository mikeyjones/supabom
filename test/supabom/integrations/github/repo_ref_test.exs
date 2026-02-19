defmodule Supabom.Integrations.GitHub.RepoRefTest do
  use ExUnit.Case, async: true

  alias Supabom.Integrations.GitHub.RepoRef

  test "parses owner/repo input" do
    assert {:ok, %{owner: "elixir-lang", repo: "elixir"}} = RepoRef.parse("elixir-lang/elixir")
  end

  test "parses github url input" do
    assert {:ok, %{owner: "phoenixframework", repo: "phoenix"}} =
             RepoRef.parse("https://github.com/phoenixframework/phoenix.git")
  end

  test "returns error for invalid format" do
    assert {:error, _reason} = RepoRef.parse("not-a-valid-repo")
  end
end
