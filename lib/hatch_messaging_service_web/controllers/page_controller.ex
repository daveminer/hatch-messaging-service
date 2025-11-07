defmodule HatchMessagingServiceWeb.PageController do
  use HatchMessagingServiceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
