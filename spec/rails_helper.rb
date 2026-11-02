require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
ENV["ORDER_LEDGER_API_KEY"] = "test-key"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"
require_relative "support/tenant_helpers"

ActiveRecord::Migration.maintain_test_schema!
ActiveRecord::Migration.verbose = false

# Company databases sit outside db:test:prepare, so bring them up to date once per run.
YAML.load_file(Rails.root.join("spec/fixtures/companies.yml")).each_value do |attributes|
  TenantRecord.provision(Company.new(attributes))
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.global_fixtures = :all
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # rspec-rails has no service type, and specs need its fixtures and transactions.
  config.define_derived_metadata(file_path: %r{/spec/services/}) { |metadata| metadata[:type] = :service }
  config.include RSpec::Rails::RailsExampleGroup, type: :service

  config.include TenantHelpers
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper, type: :job
  config.include ActiveJob::TestHelper, type: :request
end
