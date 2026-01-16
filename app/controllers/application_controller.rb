class ApplicationController < ActionController::Base
	before_action :authenticate_user!

	rescue_from ActiveRecord::RecordNotFound do
		redirect_to root_path, alert: "You don't have access to that record."
	end
end
