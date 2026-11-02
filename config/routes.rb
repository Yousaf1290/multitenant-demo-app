Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "login", to: "sessions#create"

      resources :products, only: :index

      resources :shops, only: :index do
        resources :products, only: :index, controller: "shop_products"
        resources :orders, only: %i[ show create ]
      end
    end
  end

  if Rails.env.development?
    namespace :mock do
      resources :order_reports, only: :create
    end
  end
end
