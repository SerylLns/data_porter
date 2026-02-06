# frozen_string_literal: true

DataPorter::Engine.routes.draw do
  resources :imports, only: %i[index new create show] do
    member do
      post :parse
      post :confirm
      post :cancel
    end
  end
end
