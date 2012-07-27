LiquidMerge::Application.routes.draw do
  match '/merge_liquid_templates' => 'default#merge_liquid_templates', :via => :post
  root :to => 'default#index'
end
