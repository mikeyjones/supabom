defmodule SupabomWeb.AuthOverrides do
  @moduledoc """
  Custom overrides for AshAuthentication behavior
  """
  use AshAuthentication.Phoenix.Overrides

  # Override the magic link request success redirect
  override AshAuthentication.Phoenix.Components.MagicLink do
    set :request_flash do
      {:info, "Check your email for your magic link! 📧"}
    end

    # Custom sign-in template
    set :sign_in_page_title, "Complete Sign In"
    set :sign_in_button_text, "Complete Sign In 🚀"
  end

  # Override the sign-in live view to use our custom template
  override AshAuthentication.Phoenix.SignInLive do
    set :root_class, "auth-page-custom"
  end
end
