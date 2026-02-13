defmodule Supabom.Projects.MixExsParserTest do
  use ExUnit.Case, async: true

  alias Supabom.Projects.MixExsParser

  describe "parse_content/1" do
    test "extracts both project version and elixir version" do
      content = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
            version: "0.1.0",
            elixir: "~> 1.15",
            deps: deps()
          ]
        end

        defp deps do
          []
        end
      end
      """

      assert {:ok, %{project_version: "0.1.0", elixir_version: "~> 1.15"}} =
               MixExsParser.parse_content(content)
    end

    test "handles missing version field" do
      content = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
            elixir: "~> 1.15"
          ]
        end
      end
      """

      assert {:ok, %{project_version: nil, elixir_version: "~> 1.15"}} =
               MixExsParser.parse_content(content)
    end

    test "handles missing elixir field" do
      content = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
            version: "2.5.1"
          ]
        end
      end
      """

      assert {:ok, %{project_version: "2.5.1", elixir_version: nil}} =
               MixExsParser.parse_content(content)
    end

    test "handles complex version strings" do
      content = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
            version: "1.2.3-rc1",
            elixir: "~> 1.15 or ~> 1.16"
          ]
        end
      end
      """

      assert {:ok, %{project_version: "1.2.3-rc1", elixir_version: "~> 1.15 or ~> 1.16"}} =
               MixExsParser.parse_content(content)
    end

    test "handles malformed mix.exs" do
      content = "this is not valid elixir code {{"

      assert {:error, message} = MixExsParser.parse_content(content)
      assert message =~ "parse error"
    end

    test "handles mix.exs without project function" do
      content = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def application do
          [extra_applications: [:logger]]
        end
      end
      """

      assert {:error, "Could not find project/0 function in mix.exs"} =
               MixExsParser.parse_content(content)
    end
  end

  describe "parse_file/1" do
    @tag :tmp_dir
    test "reads and parses from actual file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "mix.exs")

      content = """
      defmodule TestApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :test_app,
            version: "3.0.0",
            elixir: "~> 1.14"
          ]
        end
      end
      """

      File.write!(path, content)

      assert {:ok, %{project_version: "3.0.0", elixir_version: "~> 1.14"}} =
               MixExsParser.parse_file(path)
    end

    test "handles file read errors" do
      assert {:error, message} = MixExsParser.parse_file("/nonexistent/path/mix.exs")
      assert message =~ "Could not read"
    end
  end
end
