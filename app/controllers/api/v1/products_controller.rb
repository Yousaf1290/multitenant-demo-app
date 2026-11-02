# frozen_string_literal: true

module Api
  module V1
    class ProductsController < ApplicationController
      def index
        render_list Product.order(:id), ProductSerializer
      end
    end
  end
end
