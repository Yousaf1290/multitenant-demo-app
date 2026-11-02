module TenantJob
  extend ActiveSupport::Concern

  included do
    around_perform :select_company
  end

  private
    attr_reader :company

    def select_company(&perform)
      @company = Company.find(arguments.first)
      TenantRecord.with_company(company, &perform)
    end
end
