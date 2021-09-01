require 'omniauth-oauth2'
require 'base64'

module OmniAuth
  module Strategies
    class ClassLink < OmniAuth::Strategies::OAuth2
      option :name, :classlink
      option :client_options, {
        site:          'https://launchpad.classlink.com',
        authorize_url: '/oauth2/v2/auth',
        token_url:     '/oauth2/v2/token'
      }
      option :fields, [:email, :profile]
      option :uid_field, 'UserId'

      uid do
        raw_info[options.uid_field.to_s]
      end

      # This option bubbles up to the OmniAuth::Strategies::OAuth2
      # when we call super in the callback_phase below.
      # **State will still be verified** when login is initiated by the client.
      option :provider_ignores_state, true

      def authorize_params
        super.tap do |params|
          params[:scope] = [:email, :profile]
          params[:response_type] = :code
        end
      end

      def callback_phase
        error = request.params["error_reason"] || request.params["error"]
        stored_state = session.delete("omniauth.state")
        if error
          fail!(error, CallbackError.new(request.params["error"], request.params["error_description"] || request.params["error_reason"], request.params["error_uri"]))
        else
          # Only verify state if we've initiated login and have stored a state
          # to compare to.
          if stored_state && (!request.params["state"] || request.params["state"] != stored_state)
            fail!(:csrf_detected, CallbackError.new(:csrf_detected, "CSRF detected"))
          else
            super
          end
        end
      end

      info do
        {
          first_name: raw_info['FirstName'],
          last_name: raw_info['LastName'],
          district_id: raw_info['TenantId'],
          classlink_id: raw_info['UserId'],
          external_id: raw_info['SourcedId'],
          role: raw_info['Role'],
          email: raw_info['Email'],
          image: raw_info['ImagePath']
        }
      end

      extra do
        { 'raw_info' => raw_info }
      end

      def raw_info
        @raw_info ||= access_token.get('https://nodeapi.classlink.com/v2/my/info').parsed
      end

      private

      def callback_url
        # You can overwrite it for development purposes
        options[:redirect_uri] || super
      end
    end
  end
end
