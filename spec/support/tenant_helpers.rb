module TenantHelpers
  PASSWORD = "secret-password"

  def create_user(email = "ann@example.com")
    User.create!(name: "Ann", email: email, password: PASSWORD)
  end

  def create_shop_product(sku: "TEE", price_cents: 1500, shop: Shop.create!(name: "North"))
    shop.shop_products.create!(product: Product.create!(sku: sku, name: "#{sku} name", price_cents: price_cents))
  end

  def create_order(shop_product, user: User.first || create_user, quantity: 2, **attributes)
    order = shop_product.shop.orders.new(user: user, **attributes)
    order.order_items.new(shop_product: shop_product, quantity: quantity)
    order.tap(&:save!)
  end

  def with_csv(content)
    Tempfile.create([ "catalog", ".csv" ]) do |file|
      file.write(content)
      file.flush
      yield file.path
    end
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
