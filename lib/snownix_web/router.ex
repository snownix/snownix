defmodule SnownixWeb.Router do
  use SnownixWeb, :router

  import SnownixWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SnownixWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  ## Liveview routes
  live_session :default, on_mount: {SnownixWeb.InitAssigns, :user} do
    scope "/", SnownixWeb do
      pipe_through [:browser]

      live "/", IndexLive.Index, :index

      scope "/account" do
        live "/confirm", AuthLive.Reconfirm, :reconfirm
        live "/confirm/:token", AuthLive.Confirm, :confirm
      end

      scope "/account" do
        pipe_through [:require_authenticated_user]

        live "/settings", AccountLive.Settings, :settings
      end

      scope "/auth" do
        pipe_through [:redirect_if_user_is_authenticated]

        live "/login", AuthLive.Login, :login
        live "/register", AuthLive.Register, :register
        live "/forgot-password", AuthLive.ForgotPassword, :forgot
        live "/reset-password/:token", AuthLive.ResetPassword, :reset
      end
    end
  end

  ## Controllers
  scope "/auth", SnownixWeb do
    pipe_through [:browser, :require_authenticated_user]

    delete "/login", UserSessionController, :delete
  end

  scope "/auth", SnownixWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    post "/login", UserSessionController, :create
    post "/register", UserRegistrationController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", SnownixWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SnownixWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # scope "/", SnownixWeb do
  #   pipe_through [:browser, :require_authenticated_user]

  #   get "/users/settings", UserSettingsController, :edit
  #   put "/users/settings", UserSettingsController, :update
  #   get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  # end

  # get "/users/reset_password", UserResetPasswordController, :new
  # post "/users/reset_password", UserResetPasswordController, :create
  # get "/users/reset_password/:token", UserResetPasswordController, :edit
  # put "/users/reset_password/:token", UserResetPasswordController, :update
  # get "/users/settings", UserSettingsController, :edit
  # put "/users/settings", UserSettingsController, :update
  # get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
end
