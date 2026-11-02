require "csv"

class CatalogImport
  BATCH_SIZE = 500

  def initialize(path)
    @path = path
  end

  def call
    CSV.foreach(path, headers: true).each_slice(BATCH_SIZE) do |rows|
      products = rows.filter_map { |row| product_from(row) }.index_by { |product| product[:sku] }.values

      Product.upsert_all(products, unique_by: :sku) if products.any?
    end
  end

  private
    attr_reader :path

    def product_from(row)
      sku, name, price = row.values_at("sku", "name", "price_cents").map { |value| value.to_s.strip }
      price_cents = Integer(price, 10, exception: false)

      return { sku: sku, name: name, price_cents: price_cents } if valid?(sku, name, price_cents)

      Rails.logger.warn "Skipped catalog row: #{row.to_h}"
      nil
    end

    def valid?(sku, name, price_cents)
      sku.present? && name.present? && "#{sku}#{name}".exclude?("\0") && price_cents&.between?(0, TenantRecord::MAX_INTEGER)
    end
end
