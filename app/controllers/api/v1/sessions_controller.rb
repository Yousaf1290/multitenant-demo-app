# frozen_string_literal: true

module Api
  module V1
    class SessionsController < ApplicationController
      skip_around_action :authenticate

      rate_limit to: 10, within: 1.minute, only: :create

      def create
        credentials = params.permit(:company, :email, :password)
        raise Unauthorized if credentials.values.any? { |value| value.to_s.include?("\0") }

        company = Company.active.find_by(slug: credentials[:company])
        raise Unauthorized unless company

        user = TenantRecord.with_company(company) do
          User.authenticate_by(email: credentials[:email], password: credentials[:password])
        end
        raise Unauthorized unless user

        render json: { token: AuthToken.issue(user, company), expires_in: AuthToken::LIFETIME.to_i }
      end
    end
  end
end
