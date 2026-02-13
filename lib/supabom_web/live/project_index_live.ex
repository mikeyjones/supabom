defmodule SupabomWeb.ProjectIndexLive do
  use SupabomWeb, :live_view

  alias Supabom.Projects.Project

  @impl true
  def mount(_params, _session, socket) do
    projects =
      Project
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(authorize?: false)

    socket =
      socket
      |> assign(:page_title, "All Projects")
      |> assign(:current_scope, nil)
      |> assign(:projects, projects)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <style>
        .projects-list {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
          gap: 30px;
          margin-top: 30px;
        }

        .project-card {
          background: var(--dark-surface);
          padding: 35px;
          border-radius: 35px;
          border: 4px solid var(--purple);
          transform: rotate(-0.5deg);
          transition: all 0.4s cubic-bezier(0.68, -0.55, 0.265, 1.55);
          box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
          text-decoration: none;
          display: block;
          color: inherit;
        }

        .project-card:hover {
          transform: rotate(0deg) translateY(-10px);
          box-shadow: 0 20px 60px rgba(151, 117, 250, 0.3);
          border-color: var(--purple-bright);
        }

        .project-card h3 {
          font-size: 24px;
          font-weight: 700;
          margin-bottom: 15px;
          color: var(--text);
        }

        .project-meta {
          display: flex;
          gap: 10px;
          align-items: center;
          margin-bottom: 12px;
          flex-wrap: wrap;
        }

        .project-version {
          font-weight: 600;
          color: var(--text);
          font-size: 15px;
        }

        .project-elixir {
          font-size: 14px;
          color: var(--text-dim);
          margin-top: 8px;
          margin-bottom: 8px;
        }

        .project-date {
          font-size: 14px;
          color: var(--text-dim);
        }

        .ecosystem-badge {
          background: var(--mint);
          color: var(--dark-bg);
          padding: 4px 12px;
          border-radius: 12px;
          font-size: 14px;
          font-weight: 600;
          text-transform: uppercase;
        }

        .empty-state {
          text-align: center;
          padding: 80px 40px;
          background: var(--dark-surface);
          border-radius: 40px;
          border: 4px solid var(--mint);
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.7);
          margin-top: 30px;
        }

        .empty-state-icon {
          font-size: 80px;
          margin-bottom: 25px;
        }

        .empty-state h2 {
          font-size: 32px;
          font-weight: 700;
          margin-bottom: 15px;
          color: var(--text);
        }

        .empty-state p {
          font-size: 18px;
          color: var(--text-dim);
          margin-bottom: 30px;
          font-weight: 500;
        }

        .btn {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 18px 40px;
          font-family: 'Fredoka', sans-serif;
          font-size: 18px;
          font-weight: 700;
          border-radius: 30px;
          text-decoration: none;
          transition: all 0.4s cubic-bezier(0.68, -0.55, 0.265, 1.55);
          border: 4px solid transparent;
          cursor: pointer;
          background: var(--mint);
          color: var(--dark-bg);
          box-shadow: 0 0 30px rgba(81, 207, 102, 0.5);
          border-color: var(--mint-bright);
          transform: rotate(-1deg);
        }

        .btn:hover {
          background: var(--mint-bright);
          transform: rotate(1deg) scale(1.05) translateY(-3px);
          box-shadow: 0 0 50px rgba(81, 207, 102, 0.8);
        }

        .header-section {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
          gap: 20px;
        }

        @media (max-width: 768px) {
          .header-section {
            flex-direction: column;
            align-items: flex-start;
          }

          .header-section .btn {
            align-self: stretch;
            text-align: center;
          }
        }
      </style>

      <div class="header-section">
        <div>
          <h1 class="page-title">All Projects 📦</h1>
          <p class="page-subtitle">View and manage all your dependency scans</p>
        </div>
        <%= if @projects != [] do %>
          <a href={~p"/projects/new"} class="btn" id="create-project-btn">
            Create New Project ✨
          </a>
        <% end %>
      </div>

      <%= if @projects == [] do %>
        <div class="empty-state">
          <div class="empty-state-icon">📦</div>
          <h2>No Projects Yet</h2>
          <p>Get started by creating your first project and scanning your dependencies!</p>
          <a href={~p"/projects/new"} class="btn">Create Your First Project ✨</a>
        </div>
      <% else %>
        <div class="projects-list">
          <%= for project <- @projects do %>
            <a href={~p"/projects/#{project.id}"} class="project-card">
              <h3>{project.name}</h3>
              <div class="project-meta">
                <span class="ecosystem-badge">{project.ecosystem}</span>
                <%= if project.project_version do %>
                  <span class="project-version">v{project.project_version}</span>
                <% end %>
              </div>
              <%= if project.elixir_version do %>
                <p class="project-elixir">Elixir {project.elixir_version}</p>
              <% end %>
              <div class="project-date">
                {Calendar.strftime(project.inserted_at, "%b %d, %Y")}
              </div>
            </a>
          <% end %>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
