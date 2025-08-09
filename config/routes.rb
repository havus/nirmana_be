Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # API routes
  namespace :api do
    namespace :v1 do
      namespace :auth do
        post 'sign_up', to: 'sign_up#create'
        post 'sign_in', to: 'sign_in#create'
        post 'verify_email', to: 'verify_email#create'
        post 'forgot_password', to: 'forgot_password#create'
        post 'reset_password', to: 'reset_password#create'
        post 'change_password', to: 'change_password#create'
      end

      # Users
      get 'users/:uid', to: 'users#show'
      put 'users/:uid', to: 'users#update'

      # Projects
      resources :projects, only: [:index, :show, :create, :update, :destroy]
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
