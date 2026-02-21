# frozen_string_literal: true

RSpec.describe "DataPorter routes" do
  before(:all) do
    DataPorter::Engine.routes.draw do
      resources :imports, only: %i[index new create show destroy] do
        member do
          post :parse
          post :confirm
          post :cancel
          post :back_to_mapping
          post :dry_run
          post :resume
          patch :update_mapping
          get :status
          get :export_rejects
        end
      end

      resources :mapping_templates, except: :show
    end
  end

  it "defines import resource routes" do
    routes = DataPorter::Engine.routes
    route_set = routes.routes.map { |r| [r.defaults[:action], r.path.spec.to_s] }

    expect(route_set).to include(["index", "/imports(.:format)"])
    expect(route_set).to include(["new", "/imports/new(.:format)"])
    expect(route_set).to include(["create", "/imports(.:format)"])
    expect(route_set).to include(["show", "/imports/:id(.:format)"])
  end

  it "defines member routes for parse, confirm, cancel, dry_run, status, export_rejects, and destroy" do
    routes = DataPorter::Engine.routes
    route_set = routes.routes.map { |r| [r.defaults[:action], r.path.spec.to_s] }

    expect(route_set).to include(["parse", "/imports/:id/parse(.:format)"])
    expect(route_set).to include(["confirm", "/imports/:id/confirm(.:format)"])
    expect(route_set).to include(["cancel", "/imports/:id/cancel(.:format)"])
    expect(route_set).to include(["back_to_mapping", "/imports/:id/back_to_mapping(.:format)"])
    expect(route_set).to include(["dry_run", "/imports/:id/dry_run(.:format)"])
    expect(route_set).to include(["update_mapping", "/imports/:id/update_mapping(.:format)"])
    expect(route_set).to include(["status", "/imports/:id/status(.:format)"])
    expect(route_set).to include(["export_rejects", "/imports/:id/export_rejects(.:format)"])
    expect(route_set).to include(["resume", "/imports/:id/resume(.:format)"])
    expect(route_set).to include(["destroy", "/imports/:id(.:format)"])
  end

  it "defines mapping_templates CRUD routes" do
    routes = DataPorter::Engine.routes
    route_set = routes.routes.map { |r| [r.defaults[:action], r.path.spec.to_s] }

    expect(route_set).to include(["index", "/mapping_templates(.:format)"])
    expect(route_set).to include(["new", "/mapping_templates/new(.:format)"])
    expect(route_set).to include(["create", "/mapping_templates(.:format)"])
    expect(route_set).to include(["edit", "/mapping_templates/:id/edit(.:format)"])
    expect(route_set).to include(["update", "/mapping_templates/:id(.:format)"])
    expect(route_set).to include(["destroy", "/mapping_templates/:id(.:format)"])
  end
end
