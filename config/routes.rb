Rails.application.routes.draw do
  root "secrets#new"

  resources :secrets, only: [ :index, :new, :create, :show ], param: :token do
    collection do
      get :logs
    end
  end

  get "/s/:token", to: "secrets#show", as: :secret
  get "/created/:token", to: "secrets#created", as: :secret_created
end
