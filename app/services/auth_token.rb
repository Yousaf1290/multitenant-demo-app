class AuthToken
  ALGORITHM = "HS256"
  LIFETIME = 1.hour

  class << self
    def issue(user, company)
      JWT.encode({ sub: user.id.to_s, company_id: company.id, exp: LIFETIME.from_now.to_i }, secret, ALGORITHM)
    end

    def decode(token)
      JWT.decode(token, secret, true, algorithm: ALGORITHM).first
    end

    private
      def secret
        Rails.application.key_generator.generate_key("api auth token")
      end
  end
end
