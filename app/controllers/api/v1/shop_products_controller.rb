# frozen_string_literal: true

module Api
  module V1
    class ShopProductsController < ApplicationController
      def index
        shop = Shop.find(params[:shop_id])

        render_list shop.shop_products.includes(:product).order(:id), ShopProductSerializer
      end
    end
  end
end
