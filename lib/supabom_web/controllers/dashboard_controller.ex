defmodule SupabomWeb.DashboardController do
  use SupabomWeb, :controller

  alias Supabom.Projects.Project

  def index(conn, _params) do
    # Get the current user from the session
    current_user = conn.assigns[:current_user]

    # Fetch the last 5 projects
    projects =
      Project
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!(authorize?: false)

    render(conn, :index, current_user: current_user, projects: projects)
  end
end
