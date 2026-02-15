defmodule Supabom.Accounts.User do
  @moduledoc """
  User resource for authentication.
  """

  use Ash.Resource,
    domain: Supabom.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  postgres do
    table("users")
    repo(Supabom.Repo)
  end

  authentication do
    tokens do
      enabled?(true)
      token_resource(Supabom.Accounts.Token)
      signing_secret(Supabom.Accounts.Secrets)
    end

    session_identifier(:jti)

    strategies do
      magic_link do
        identity_field(:email)
        require_interaction?(false)
        registration_enabled?(true)

        sender(fn user_or_email, token, _opts ->
          # Handle both existing users (map) and new registrations (email string)
          email =
            if is_binary(user_or_email),
              do: user_or_email,
              else: to_string(user_or_email.email)

          endpoint_url = SupabomWeb.Endpoint.url()

          magic_link =
            endpoint_url
            |> URI.parse()
            |> URI.merge("/auth/user/magic_link?token=#{token}")
            |> URI.to_string()

          # Log to console for development
          IO.puts("\n==============================================")
          IO.puts("Magic link for #{email}:")
          IO.puts(magic_link)
          IO.puts("==============================================\n")

          # Also send via Swoosh so it appears in /dev/mailbox
          import Swoosh.Email

          new()
          |> to(email)
          |> from({"SupaBOM", "noreply@supabom.com"})
          |> subject("Your SupaBOM Magic Link ✨")
          |> html_body("""
          <div style="font-family: 'Fredoka', sans-serif; padding: 40px; background: #1a1625; color: #f8f9fa;">
            <h1 style="color: #ff6b6b;">Welcome to SupaBOM! 👋</h1>
            <p style="font-size: 18px; margin: 20px 0;">Click the button below to sign in:</p>
            <a href="#{magic_link}" style="display: inline-block; padding: 18px 45px; background: #ff6b6b; color: white; text-decoration: none; border-radius: 30px; font-weight: 700; font-size: 18px;">
              Sign In 🚀
            </a>
            <p style="margin-top: 30px; color: #adb5bd; font-size: 14px;">
              Or copy and paste this link: <br>
              <code style="background: #251e35; padding: 10px; display: block; margin-top: 10px; border-radius: 10px;">#{magic_link}</code>
            </p>
          </div>
          """)
          |> text_body("Welcome to SupaBOM! Click this link to sign in: #{magic_link}")
          |> Supabom.Mailer.deliver()

          :ok
        end)
      end

      github do
        client_id(Supabom.Accounts.Secrets)
        client_secret(Supabom.Accounts.Secrets)
        redirect_uri(Supabom.Accounts.Secrets)
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_email, [:email])
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      prepare(build(load: [:email]))
    end

    create :create do
      accept([:email])
      primary?(true)
    end

    update :update do
      accept([:email])
      primary?(true)
    end

    create :register_with_github do
      argument(:user_info, :map, allow_nil?: false)
      argument(:oauth_tokens, :map, allow_nil?: false)

      upsert?(true)
      upsert_identity(:unique_email)

      change(AshAuthentication.GenerateTokenChange)

      change(fn changeset, _ ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        email = Map.get(user_info, "email") || Map.get(user_info, :email)

        if email do
          Ash.Changeset.change_attribute(changeset, :email, email)
        else
          changeset
        end
      end)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end
end
