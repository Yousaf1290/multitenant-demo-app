require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:alpha) { companies(:alpha) }
  let(:beta) { companies(:beta) }
  let!(:user) { TenantRecord.with_company(alpha) { create_user } }
  let(:token) { AuthToken.issue(user, alpha) }

  it "returns a token that opens protected endpoints" do
    post "/api/v1/login", params: { company: "alpha", email: "ann@example.com", password: TenantHelpers::PASSWORD }, as: :json

    expect(response).to have_http_status(:ok)

    get "/api/v1/shops", headers: bearer(response.parsed_body["token"])
    expect(response).to have_http_status(:ok)
  end

  it "gives the same response for every login failure" do
    bodies = [
      { company: "alpha", email: "ann@example.com", password: "wrong" },
      { company: "alpha", email: "nobody@example.com", password: TenantHelpers::PASSWORD },
      { company: "nowhere", email: "ann@example.com", password: TenantHelpers::PASSWORD }
    ].map do |credentials|
      post "/api/v1/login", params: credentials, as: :json
      expect(response).to have_http_status(:unauthorized)
      response.body
    end

    expect(bodies.uniq.size).to eq(1)
  end

  it "refuses a request with no token or a forged one" do
    forged = JWT.encode({ sub: user.id.to_s, company_id: alpha.id, exp: 1.hour.from_now.to_i }, "x" * 64, "HS256")

    [ {}, bearer(forged) ].each do |headers|
      get "/api/v1/shops", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "refuses an expired token" do
    issued = token

    travel 61.minutes do
      get "/api/v1/shops", headers: bearer(issued)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "locks out a suspended company, even with a valid token" do
    issued = token
    alpha.update!(status: "suspended")

    get "/api/v1/shops", headers: bearer(issued)

    expect(response).to have_http_status(:unauthorized)
  end

  it "only ever reads the company in the token" do
    TenantRecord.with_company(alpha) { Product.create!(sku: "ALPHA-ONLY", name: "Alpha", price_cents: 1) }
    beta_token = TenantRecord.with_company(beta) do
      Product.create!(sku: "BETA-ONLY", name: "Beta", price_cents: 1)
      AuthToken.issue(create_user, beta)
    end

    get "/api/v1/products", params: { company: "alpha" }, headers: bearer(beta_token)

    expect(response.parsed_body["data"].map { |row| row.dig("attributes", "sku") }).to eq([ "BETA-ONLY" ])
  end
end
