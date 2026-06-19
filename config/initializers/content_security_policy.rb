# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
	config.content_security_policy do |policy|
		policy.default_src :self, :https
		policy.base_uri :self
		policy.frame_ancestors :none
		policy.object_src :none

		# Allow app assets plus known external APIs/providers used today.
		policy.script_src :self, :https, :unsafe_inline
		policy.style_src :self, :https, :unsafe_inline
		policy.img_src :self, :https, :data, :blob
		policy.font_src :self, :https, :data
		policy.connect_src :self, :https, :ws, :wss
	end

	config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
	config.content_security_policy_nonce_directives = %w(script-src style-src)

	report_only = ENV.fetch('CSP_REPORT_ONLY', Rails.env.production? ? 'true' : 'false')
	config.content_security_policy_report_only = ActiveModel::Type::Boolean.new.cast(report_only)
end
