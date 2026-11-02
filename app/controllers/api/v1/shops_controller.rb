# frozen_string_literal: true

module Api
  module V1
    class ShopsController < ApplicationController
      def index
        render_list Shop.order(:id), ShopSerializer
      end
    end
  end
end
