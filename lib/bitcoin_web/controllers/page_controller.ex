defmodule BitcoinWeb.PageController do
  use BitcoinWeb, :controller

  def index(conn, _params) do
    spawn fn -> Project4.main(100) end
    render(conn, "index.html")

  end
end
