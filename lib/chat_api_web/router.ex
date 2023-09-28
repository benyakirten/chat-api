defmodule ChatApiWeb.Router do
  use ChatApiWeb, :router

  alias ChatApiWeb.{AuthController, ConversationController}

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
    post("/signout", AuthController, :signout)
    post("/register", AuthController, :register)
    post("/signout", AuthController, :signout)
    post("/confirm_email", AuthController, :confirm_email)
    post("/reset_password", AuthController, :reset_password)
  end

  scope "/api", ChatApiWeb do
    pipe_through(:api)
    resources "/conversations", ConversationController, except: [:new, :edit]
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
