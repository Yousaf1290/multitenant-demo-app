require "rails_helper"

RSpec.describe CatalogImport do
  around { |example| TenantRecord.with_company(companies(:alpha)) { example.run } }

  def import(rows)
    with_csv("sku,name,price_cents\n#{rows}") { |path| described_class.new(path).call }
  end

  def row_of(sku)
    Product.where(sku: sku).pick(:name, :price_cents)
  end

  it "creates new products, updates existing ones and leaves the rest alone" do
    Product.create!(sku: "TEE", name: "Tee", price_cents: 1500)
    Product.create!(sku: "LEGACY", name: "Legacy", price_cents: 100)

    import "TEE,Tee v2,2000\nNEW,New Thing,300\n"

    expect(row_of("TEE")).to eq([ "Tee v2", 2000 ])
    expect(row_of("NEW")).to eq([ "New Thing", 300 ])
    expect(row_of("LEGACY")).to eq([ "Legacy", 100 ])
  end

  it "skips bad rows and still imports the good ones" do
    import "GOOD,Good One,100\n,No Sku,100\nNONAME,,100\nTEXT,Text Price,abc\nNEG,Negative,-1\nHUGE,Too Big,2147483648\n"

    expect(Product.pluck(:sku)).to eq([ "GOOD" ])
  end

  it "keeps the last row when a sku repeats" do
    import "SAME,First,1\nSAME,Second,2\n"

    expect(row_of("SAME")).to eq([ "Second", 2 ])
  end

  it "updates linked shop products but never shop prices or past orders" do
    linked = create_shop_product(sku: "TEE", price_cents: 1500)
    override = linked.shop.shop_products.create!(product: Product.create!(sku: "MUG", name: "Mug", price_cents: 900), price_cents: 1100)
    order = create_order(linked)

    import "TEE,Tee v2,2000\nMUG,Mug,950\n"

    expect(linked.reload.price_cents).to eq(2000)
    expect(override.reload.price_cents).to eq(1100)
    expect(order.order_items.first.unit_price_cents).to eq(1500)
    expect(order.reload.total_cents).to eq(3000)
  end
end
