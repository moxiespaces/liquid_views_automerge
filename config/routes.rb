LiquidMerge::Application.routes.draw do
  get "default/index"
  post "default/merge_liquid_templates"
  root :to => 'default#index'
end
