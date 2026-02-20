# frozen_string_literal: true

DataPorter::Engine.routes.draw do
  resources :mapping_templates

  resources :imports, path: "/", only: %i[index new create show destroy] do
    member do
      post :parse
      post :confirm
      post :cancel
      post :back_to_mapping
      post :dry_run
      patch :update_mapping
      get :status
      get :export_rejects
    end
  end
end
