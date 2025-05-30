Rails.application.routes.draw do
  # dummy rails issue
  default_url_options host: "http://127.0.0.1:3000"

  root "secrets#new"

  resources :secrets, only: [ :index, :new, :create, :destroy ], param: :token do
    collection do
      get :logs
    end
  end

  get "/s/:token", to: "secrets#show", as: :view_secret
  get "/created/:token", to: "secrets#created", as: :secret_created
end
