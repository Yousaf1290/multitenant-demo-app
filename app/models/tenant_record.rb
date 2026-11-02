# Base class for models stored in a company's own database. Queries must run
# inside with_company. The "tenant" database in config/database.yml is only a
# template: it owns the migrations, and each company copies its settings.
class TenantRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to shards: { template: { writing: :tenant } }

  # This shard has no connection, so tenant queries raise until a company is selected.
  self.default_shard = :no_company_selected

  REGISTERED_SHARDS = Concurrent::Map.new

  # Largest value a Postgres integer column holds; beyond it a save raises instead of failing validation.
  MAX_INTEGER = 2_147_483_647

  class << self
    def with_company(company, &block)
      register(company)
      connected_to(shard: company.shard) { prohibit_shard_swapping(&block) }
    end

    # Rake tasks and seeds only: migrating repoints ActiveRecord::Base for the whole process.
    def provision(company)
      create_database(company)
      migrate(company)
    end

    def migrate(company)
      ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(db_config_for(company)) do |connection|
        connection.pool.migration_context.migrate
      end
    end

    private
      # Once per shard: establishing a connection again would replace the live pool.
      def register(company)
        REGISTERED_SHARDS.compute_if_absent(company.shard) do
          connection_handler.establish_connection(db_config_for(company), owner_name: TenantRecord, shard: company.shard)
        end
      end

      # Not DatabaseTasks.create, which leaves ActiveRecord::Base connected to the new database.
      def create_database(company)
        ActiveRecord::Base.with_connection { |connection| connection.create_database(company.database_name) }
      rescue ActiveRecord::DatabaseAlreadyExists
        nil
      end

      def db_config_for(company)
        template = configurations.configs_for(env_name: Rails.env, name: "tenant")
        ActiveRecord::DatabaseConfigurations::HashConfig.new(
          Rails.env, company.slug, template.configuration_hash.merge(database: company.database_name)
        )
      end
  end
end
