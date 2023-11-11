defmodule ChatApiWeb.Router do
  # NEVER EVER ALIAS YOUR CONTROLLERS IN THIS FILE
  use ChatApiWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(ChatApiWeb.Plugs.Token)
  end

  pipeline :auth do
    plug(:accepts, ["json"])
  end

  scope "/auth", ChatApiWeb do
    pipe_through(:auth)
    post("/login", AuthController, :login)
    post("/register", AuthController, :register)
    post("/refresh", AuthController, :refresh_auth)
    post("/confirm", AuthController, :confirm_user)
    post("/password/request", AuthController, :request_password_reset_token)
    post("/password/confirm", AuthController, :confirm_password_reset_token)
    post("/password/reset", AuthController, :reset_password)
  end

  scope "/api", ChatApiWeb do
    pipe_through(:api)
    post("/signout", ProfileController, :signout)
    post("/signout_all", ProfileController, :signout_all)
    post("/token/email_confirm", ProfileController, :request_new_confirmation_token)
    post("/token/email_change", ProfileController, :request_email_change_token)
    post("/recents", ProfileController, :set_recents)
    patch("/password", ProfileController, :update_password)
    patch("/email", ProfileController, :update_email)
    patch("/profile", ProfileController, :update_profile)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:chat_api, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: ChatApiWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
