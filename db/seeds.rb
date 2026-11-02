return if Rails.env.production?

password = "password123"

companies = [
  {
    name: "Acme Retail",
    slug: "acme",
    catalog: { "TSHIRT-M" => [ "T-Shirt (M)", 1500 ], "MUG-300" => [ "Coffee Mug", 900 ], "CAP-BLK" => [ "Black Cap", 1200 ] }
  },
  {
    name: "Globex Stores",
    slug: "globex",
    catalog: { "USB-C-1M" => [ "USB-C Cable", 800 ], "MOUSE-W" => [ "Wireless Mouse", 2500 ], "STAND-AL" => [ "Laptop Stand", 4200 ] }
  }
]

companies.each do |details|
  company = Company.find_or_create_by!(slug: details[:slug]) { |new_company| new_company.name = details[:name] }
  TenantRecord.provision(company)

  TenantRecord.with_company(company) do
    _manager, cashier = %w[manager cashier].map do |job|
      User.find_or_create_by!(email: "#{job}@#{company.slug}.example") do |user|
        user.name = "#{company.name} #{job.capitalize}"
        user.password = password
      end
    end

    products = details[:catalog].map do |sku, (name, price_cents)|
      Product.find_or_create_by!(sku: sku) do |product|
        product.name = name
        product.price_cents = price_cents
      end
    end

    downtown = Shop.find_or_create_by!(name: "Downtown")
    products.each { |product| downtown.shop_products.find_or_create_by!(product: product) }

    airport = Shop.find_or_create_by!(name: "Airport")
    airport.shop_products.find_or_create_by!(product: products.second)
    airport.shop_products.find_or_create_by!(product: products.first) do |shop_product|
      shop_product.price_cents = products.first.price_cents + 300
    end
    airport.shop_products.find_or_create_by!(sku: "AIRPORT-GIFT") do |shop_product|
      shop_product.name = "Airport Gift Bag"
      shop_product.price_cents = 500
    end

    [ downtown, airport ].each do |shop|
      next if shop.orders.exists?

      order = shop.orders.new(user: cashier)
      shop.shop_products.includes(:product).each do |shop_product|
        order.order_items.new(shop_product: shop_product, quantity: 2)
      end
      order.save!
    end
  end
end

puts "Seeded. Log in with company acme, email manager@acme.example, password #{password}"
