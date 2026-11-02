# frozen_string_literal: true

module Mock
  class OrderReportsController < ActionController::API
    def create
      render json: { id: SecureRandom.uuid }, status: :created
    end
  end
end
