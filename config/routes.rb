Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :appointments, only: [:create] do
        member do
          patch :cancel
        end
      end
      post "auth/token", to: "auth#token"
    end
  end
end
