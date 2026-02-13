defmodule SupabomWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SupabomWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <style>
      .container {
        max-width: 1200px;
        margin: 0 auto;
        padding: 0 30px;
        position: relative;
        z-index: 1;
      }

      header {
        padding: 30px 0;
      }

      nav {
        display: flex;
        justify-content: space-between;
        align-items: center;
        background: var(--dark-surface);
        padding: 20px 35px;
        border-radius: 60px;
        box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5), 0 0 0 3px var(--purple);
        transform: rotate(-0.5deg);
        transition: all 0.3s ease;
      }

      nav:hover {
        transform: rotate(0deg) translateY(-2px);
        box-shadow: 0 15px 50px rgba(0, 0, 0, 0.6), 0 0 20px var(--purple);
      }

      .logo-link {
        text-decoration: none;
      }

      .logo {
        font-size: 32px;
        font-weight: 700;
        background: linear-gradient(135deg, var(--coral) 0%, var(--yellow) 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
        transform: rotate(2deg);
        transition: transform 0.3s ease;
        filter: drop-shadow(0 0 10px rgba(255, 107, 107, 0.5));
      }

      .logo:hover {
        transform: rotate(-2deg) scale(1.05);
      }

      .nav-right {
        display: flex;
        align-items: center;
        gap: 20px;
      }

      .user-info {
        color: var(--text-dim);
        font-size: 14px;
        font-weight: 500;
      }

      .nav-links {
        display: flex;
        gap: 15px;
        list-style: none;
      }

      .nav-links a {
        color: var(--text);
        text-decoration: none;
        font-size: 15px;
        font-weight: 600;
        transition: all 0.3s ease;
        padding: 8px 18px;
        border-radius: 20px;
        border: 2px solid transparent;
      }

      .nav-links a:hover {
        border-color: var(--coral);
        background: var(--coral);
        color: white;
        transform: scale(1.05);
      }

      .main-content {
        padding: 40px 0;
      }

      .page-title {
        font-size: 48px;
        font-weight: 700;
        margin-bottom: 20px;
        color: var(--text);
      }

      .page-subtitle {
        font-size: 18px;
        color: var(--text-dim);
        margin-bottom: 30px;
        font-weight: 500;
      }
    </style>

    <div class="container">
      <header>
        <nav>
          <a href="/" class="logo-link">
            <div class="logo">SupaBOM ✨</div>
          </a>
          <div class="nav-right">
            <span class="user-info">
              <%= if assigns[:current_user] do %>
                {assigns[:current_user].email}
              <% end %>
            </span>
            <ul class="nav-links">
              <li><a href="/sign-out">Sign Out</a></li>
            </ul>
          </div>
        </nav>
      </header>

      <main class="main-content">
        {render_slot(@inner_block)}
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
