class Users::RegistrationsController < Devise::RegistrationsController
  before_action :check_email_allowlist, only: [:create]

  private

  def check_email_allowlist
    email = sign_up_params[:email].to_s.strip.downcase
    unless User.email_allowed?(email)
      flash[:alert] = "Registration is restricted to approved email addresses."
      redirect_to new_user_registration_path and return
    end
  end
end
