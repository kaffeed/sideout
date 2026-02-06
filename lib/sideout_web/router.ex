defmodule SideoutWeb.Router do
  use SideoutWeb, :router

  import SideoutWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SideoutWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SideoutWeb do
    pipe_through :browser

    # Public routes - mount current_user (can be nil)
    live_session :public,
      on_mount: [{SideoutWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive, :index
      live "/s/:share_token", SessionSignupLive, :show
      live "/cancel/:token", CancellationLive, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", SideoutWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sideout, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SideoutWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", SideoutWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{SideoutWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", SideoutWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SideoutWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  ## Trainer routes (authenticated)

  scope "/trainer", SideoutWeb.Trainer do
    pipe_through [:browser, :require_authenticated_user]

    live_session :trainer,
      on_mount: [{SideoutWeb.UserAuth, :ensure_authenticated}] do
      # Dashboard
      live "/dashboard", DashboardLive, :index

      # Clubs
      live "/clubs", ClubLive.Index, :index
      live "/clubs/new", ClubLive.Index, :new
      live "/clubs/:id", ClubLive.Show, :show
      live "/clubs/:id/edit", ClubLive.Show, :edit

      # Session Templates
      live "/templates", TemplateLive.Index, :index
      live "/templates/new", TemplateLive.Index, :new
      live "/templates/:id/edit", TemplateLive.Index, :edit
      live "/templates/:id", TemplateLive.Show, :show

      # Sessions
      live "/sessions", SessionLive.Index, :index
      live "/sessions/new", SessionLive.Index, :new
      live "/sessions/:id", SessionLive.Show, :show
      live "/sessions/:id/edit", SessionLive.Index, :edit
      live "/sessions/:id/attendance", AttendanceLive, :index

      # Players
      live "/players", PlayerLive.Index, :index
      live "/players/new", PlayerLive.Index, :new
      live "/players/:id", PlayerLive.Show, :show
      live "/players/:id/edit", PlayerLive.Index, :edit
    end
  end

  scope "/", SideoutWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{SideoutWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
