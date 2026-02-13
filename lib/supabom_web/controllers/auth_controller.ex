defmodule SupabomWeb.AuthController do
  use SupabomWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def request(conn, _params) do
    render(conn, :request)
  end

  def redirect_to_sign_in(conn, _activity, user_or_email, _token) do
    email = extract_email(user_or_email)

    # Redirect directly to the check-email page so the flow is robust
    # even when client-side JavaScript doesn't run.
    encoded_email = URI.encode_www_form(email)

    conn
    |> put_session(:magic_link_email, email)
    |> redirect(to: "/check-email?email=#{encoded_email}")
  end

  def check_email(conn, params) do
    email = params["email"] || get_session(conn, :magic_link_email) || "your inbox"

    conn
    |> delete_session(:magic_link_email)
    |> render(:check_email, email: email)
  end

  def success(conn, activity, user_or_email, token) do
    if request_activity?(activity) do
      redirect_to_sign_in(conn, activity, user_or_email, token)
    else
      user = user_or_email
      return_to = get_session(conn, :return_to) || ~p"/dashboard"

      conn
      |> delete_session(:return_to)
      |> store_in_session(user)
      |> assign(:current_user, user)
      |> put_flash(:info, "Welcome! 🎉")
      |> redirect(to: return_to)
    end
  end

  def failure(conn, activity, reason) do
    # Log the actual error for debugging
    IO.inspect({activity, reason}, label: "AUTH FAILURE")

    conn
    |> put_flash(:error, "Something went wrong. Please try again.")
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:supabom)
    |> put_flash(:info, "You have been signed out")
    |> redirect(to: return_to)
  end

  defp extract_email(user_or_email) when is_binary(user_or_email), do: user_or_email
  defp extract_email(%{email: email}) when is_binary(email), do: email
  defp extract_email(_), do: "your inbox"

  defp request_activity?(%{action: :request}), do: true
  defp request_activity?(%{name: :request}), do: true
  defp request_activity?({_, :request}), do: true
  defp request_activity?(:request), do: true
  defp request_activity?("request"), do: true
  defp request_activity?(_), do: false
end
