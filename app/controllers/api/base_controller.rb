module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_user!

    private

    def authenticate_api_user!
      token = request.headers["Authorization"]&.remove("Bearer ")
      @current_user = User.authenticate_by_api_token(token)
      render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
    end

    def current_user
      @current_user
    end
  end
end
