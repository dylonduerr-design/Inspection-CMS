# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  
  resources :reports do
    resources :checklist_entries, only: [:create, :update] 
    member do
      post :submit_for_qc
      post :approve
      post :request_revision
      get  :export_word  # Legacy sync export (deprecated)
      post :start_export # New async export
      get  :ai_payload   # Testing: AI payload preview
      
      # AI generation endpoints
      post :generate_work_summary
      post :generate_commentary
      get  :ai_status
    end
    
    resources :report_exports, only: [:show] do
      member do
        get :download
      end
    end
  end

  # --- MAESTRO CHANGE: Nest Bid Items under Projects ---
  resources :projects do
    resources :bid_items # URL: /projects/1/bid_items/new
    resources :approved_equipments, only: [:create, :destroy]
  end
  
  resources :phases
  resources :spec_items, only: [:index, :update]
  
 

  root "reports#index"
end