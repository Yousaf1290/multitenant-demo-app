# frozen_string_literal: true

module Api
  module V1
    class ApplicationController < ActionController::API
      class Unauthorized < StandardError; end

      MAX_PAGE_SIZE = 100

      # Wrapping reads the model's columns before any company is selected, which raises.
      wrap_parameters false

      around_action :authenticate

      rescue_from ActiveRecord::RecordNotFound do |exception|
        render_errors :not_found, title: "Record not exists", detail: "Could not find #{exception.model} with given id"
      end

      rescue_from ActiveRecord::RecordInvalid do |exception|
        render_errors :unprocessable_content, *exception.record.errors.map { |error| { title: error.attribute, detail: error.message } }
      end

      rescue_from ActionController::ParameterMissing do |exception|
        render_errors :bad_request, title: "Invalid request", detail: exception.message
      end

      rescue_from Unauthorized, JWT::DecodeError do
        render_errors :unauthorized, title: "Unauthorized", detail: "Missing or invalid credentials"
      end

      rescue_from ActionController::TooManyRequests do
        render_errors :too_many_requests, title: "Too many requests", detail: "Please try again later"
      end

      private
        attr_reader :current_user

        def authenticate
          claims = AuthToken.decode(request.authorization.to_s.delete_prefix("Bearer "))
          company = Company.active.find_by(id: claims["company_id"])
          raise Unauthorized unless company

          TenantRecord.with_company(company) do
            @current_user = User.find_by(id: claims["sub"])
            raise Unauthorized unless current_user

            yield
          end
        end

        def render_object(object, serializer, status: :ok, **options)
          render json: serializer.new(object, options).serializable_hash, status: status
        end

        def render_list(records, serializer)
          paging = params.permit(:page, :per_page)
          results = paginate_results(records, paging[:page], paging[:per_page])

          render_object results, serializer, meta: {
            current_page: results.current_page, total_pages: results.total_pages, total_count: results.total_count
          }
        end

        def paginate_results(records, page, page_size)
          page_size = nil if page_size.to_i.zero?

          records.page(page.to_i.clamp(1, TenantRecord::MAX_INTEGER)).per(page_size, max_per_page: MAX_PAGE_SIZE)
        end

        def render_errors(status, *errors)
          code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status]

          render json: { errors: errors.map { |error| { status: code, **error } } }, status: status
        end
    end
  end
end
