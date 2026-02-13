defmodule SupabomWeb.Router do
  use SupabomWeb, :router

  import AshAuthentication.Phoenix.Router
  import SupabomWeb.Plugs.AuthPlugs

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SupabomWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_current_user
  end

  pipeline :require_authenticated_user do
    plug :require_authenticated
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SupabomWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Custom sign-in page with playful design
    get "/sign-in", AuthController, :request
    get "/check-email", AuthController, :check_email
    sign_out_route AuthController

    auth_routes AuthController, Supabom.Accounts.User,
      path: "/auth",
      on_success: [
        {AshAuthentication.Strategy.MagicLink, :request, {SupabomWeb.AuthController, :redirect_to_sign_in}}
      ],
      overrides: [SupabomWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
  end

  # Protected routes - require authentication
  scope "/", SupabomWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/dashboard", DashboardController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", SupabomWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:supabom, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SupabomWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
