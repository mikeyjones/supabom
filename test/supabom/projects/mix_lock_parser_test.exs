defmodule Supabom.Projects.MixLockParserTest do
  use ExUnit.Case, async: true

  alias Supabom.Projects.MixLockParser

  test "parse_content/1 parses package versions from mix.lock" do
    mix_lock = """
    %{
      "ash" => {:hex, :ash, "3.16.0", "hash", [:mix], [], "hexpm", "outer"},
      "phoenix" => {:hex, :phoenix, "1.8.3", "hash", [:mix], [], "hexpm", "outer"}
    }
    """

    assert {:ok, dependencies} = MixLockParser.parse_content(mix_lock)

    assert dependencies == [
             %{manager: "hex", package: "ash", version: "3.16.0"},
             %{manager: "hex", package: "phoenix", version: "1.8.3"}
           ]
  end

  test "parse_content/1 returns an error for invalid lockfile content" do
    assert {:error, message} = MixLockParser.parse_content("not a map")
    assert message =~ "expected a literal map"
  end
end
