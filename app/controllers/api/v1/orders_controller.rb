# frozen_string_literal: true

module Api
  module V1
    class OrdersController < ApplicationController
      before_action :set_shop

      def show
        render_order @shop.orders.find(params[:id])
      end

      def create
        order = @shop.orders.new(user: current_user)

        item_params.each do |item|
          order.order_items.new(shop_product: @shop.shop_products.find(item[:shop_product_id]), quantity: item[:quantity])
        end

        order.save!
        queue_report(order)

        render_order order, status: :created
      end

      private
        def queue_report(order)
          ReportOrderJob.perform_later(current_company.id, order.id)
        rescue SolidQueue::Job::EnqueueError => error
          logger.error "Order #{order.id} not queued for reporting: #{error.message}"
        end

        def set_shop
          @shop = Shop.find(params[:shop_id])
        end

        def item_params
          params.expect(order: [ items: [ [ :shop_product_id, :quantity ] ] ])[:items]
        end

        def render_order(order, status: :ok)
          render_object order, OrderSerializer, status: status, include: [ :order_items ]
        end
    end
  end
end
