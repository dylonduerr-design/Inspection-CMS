class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [:microsoft_graph]

  # POST /users/auth/microsoft_graph/callback
  def microsoft_graph
    auth = request.env["omniauth.auth"]

    # --- Tenant lock-down (single-tenant) ---
    expected_tenant = ENV["AZURE_TENANT_ID"]
    token_tenant = auth.extra&.raw_info&.tid rescue nil

    if expected_tenant.present? && token_tenant.present? && token_tenant != expected_tenant
      flash[:alert] = "Sign-in is restricted to your organization."
      redirect_to new_user_session_path and return
    end

    @user = User.from_microsoft_omniauth(auth)

    if @user&.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Microsoft") if is_navigational_format?
    else
      flash[:alert] = @user&.errors&.full_messages&.join(", ") || "Unable to sign in with Microsoft."
      redirect_to new_user_session_path
    end
  end

  def failure
    flash[:alert] = "Microsoft sign-in failed: #{failure_message}"
    redirect_to new_user_session_path
  end
end
