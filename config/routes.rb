Rosa::Application.routes.draw do
  # XML RPC
  match 'api/xmlrpc' => 'rpc#xe_index'
  
  devise_for :users, :controllers => {:omniauth_callbacks => 'users/omniauth_callbacks'} do
    get '/users/auth/:provider' => 'users/omniauth_callbacks#passthru'
  end
  
  resources :users
  
  resources :roles do
    collection do
      get 'get_dump'
      post 'get_dump'
      post 'load_from_dump'
    end
  end

  resources :event_logs, :only => :index

  #resources :downloads, :only => :index
  match 'statistics/' => 'downloads#index', :as => :downloads
  match 'statistics/refresh' => 'downloads#refresh', :as => :downloads_refresh

  resources :categories do
    get :platforms, :on => :collection
  end

  match '/private/:platform_name/*file_path' => 'privates#show'

  match 'build_lists/' => 'build_lists#all', :as => :all_build_lists
  match 'build_lists/:id/cancel/' => 'build_lists#cancel', :as => :build_list_cancel
  
  resources :auto_build_lists, :only => [:index, :create, :destroy] do
  end

  resources :personal_repositories, :only => [:show] do
    member do
      get :settings
      get :change_visibility
      get :add_project
      get :remove_project
    end
  end

  resources :platforms do
    resources :private_users, :except => [:show, :destroy, :update]

    member do
      get 'freeze'
      get 'unfreeze'
      get 'clone'
      post 'clone'
    end

    collection do
      get 'easy_urpmi'
    end

    resources :products do
      member do
        get :clone
        get :build
      end
    end

    resources :repositories do
    end

    resources :categories, :only => [:index, :show]
  end

  resources :projects do
    resource :repo, :controller => "git/repositories", :only => [:show]
    resources :build_lists, :only => [:index, :show] do
      collection do
        get :recent
        post :filter
      end
      member do
        post :publish
      end
    end

    resources :collaborators, :only => [:index, :edit, :update] do
      collection do
        get :edit
        post :update
      end
      member do
        post :update
      end
    end
#    resources :groups, :controller => 'project_groups' do
#    end

    member do
      get :build
      post :process_build
    end
    collection do
      get :auto_build
    end
  end

  resources :repositories do
    member do
      get :add_project
      get :remove_project
    end
  end

  resources :users, :groups do
    resources :platforms, :only => [:new, :create]

    resources :projects, :only => [:new, :create]

    resources :repositories, :only => [:new, :create]
  end

  match '/catalogs', :to => 'categories#platforms', :as => :catalogs

  match 'build_lists/status_build', :to => "build_lists#status_build"
  match 'build_lists/post_build', :to => "build_lists#post_build"
  match 'build_lists/pre_build', :to => "build_lists#pre_build"
  match 'build_lists/circle_build', :to => "build_lists#circle_build"
  match 'build_lists/new_bbdt', :to => "build_lists#new_bbdt"

  match 'product_status', :to => 'products#product_status'

  # Tree
  match '/projects/:project_id/git/tree/:treeish(/*path)', :controller => "git/trees", :action => :show, :treeish => /[0-9a-zA-Z_.\-]*/, :defaults => { :treeish => :master }, :as => :tree
         
  # Commits
  match '/projects/:project_id/git/commits/:treeish(/*path)', :controller => "git/commits", :action => :index, :treeish => /[0-9a-zA-Z_.\-]*/, :defaults => { :treeish => :master }, :as => :commits
  match '/projects/:project_id/git/commit/:id(.:format)', :controller => "git/commits", :action => :show, :defaults => { :format => :html }, :as => :commit
         
  # Blobs
  match '/projects/:project_id/git/blob/:treeish/*path', :controller => "git/blobs", :action => :show, :treeish => /[0-9a-zA-Z_.\-]*/, :defaults => { :treeish => :master }, :as => :blob
  match '/projects/:project_id/git/commit/blob/:commit_hash/*path', :controller => "git/blobs", :action => :show, :project_name => /[0-9a-zA-Z_.\-]*/, :as => :blob_commit
         
  # Blame
  match '/projects/:project_id/git/blame/:treeish/*path', :controller => "git/blobs", :action => :blame, :treeish => /[0-9a-zA-Z_.\-]*/, :defaults => { :treeish => :master }, :as => :blame
  match '/projects/:project_id/git/commit/blame/:commit_hash/*path', :controller => "git/blobs", :action => :blame, :as => :blame_commit
         
  # Raw  
  match '/projects/:project_id/git/raw/:treeish/*path', :controller => "git/blobs", :action => :raw, :treeish => /[0-9a-zA-Z_.\-]*/, :defaults => { :treeish => :master }, :as => :raw
  match '/projects/:project_id/git/commit/raw/:commit_hash/*path', :controller => "git/blobs", :action => :raw, :as => :raw_commit

  root :to => "platforms#index"
end
