# frozen_string_literal: true

DataPorter::Engine.routes.draw do
  resources :imports, only: %i[index new create show destroy] do
    member do
      post :parse
      post :confirm
      post :cancel
      post :dry_run
      patch :update_mapping
      get :status
      get :export_rejects
    end
  end

  resources :mapping_templates, except: :show
end
