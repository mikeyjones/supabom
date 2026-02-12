defmodule SupabomWeb.PageController do
  use SupabomWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
