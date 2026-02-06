# frozen_string_literal: true

RSpec.describe "DataPorter routes" do
  before(:all) do
    DataPorter::Engine.routes.draw do
      resources :imports, only: %i[index new create show] do
        member do
          post :parse
          post :confirm
          post :cancel
        end
      end
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

  it "defines member routes for parse, confirm, and cancel" do
    routes = DataPorter::Engine.routes
    route_set = routes.routes.map { |r| [r.defaults[:action], r.path.spec.to_s] }

    expect(route_set).to include(["parse", "/imports/:id/parse(.:format)"])
    expect(route_set).to include(["confirm", "/imports/:id/confirm(.:format)"])
    expect(route_set).to include(["cancel", "/imports/:id/cancel(.:format)"])
  end
end
