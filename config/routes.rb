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
      post :resume
      post :update_mapping
      patch :update_mapping
      post :update_record
      patch :update_record
      get :status
      get :export_rejects
    end
  end
end
