Capistrano::Configuration.instance(:must_exist).load do
  namespace :deploy do
    set :unicorn_binary, "bundle exec unicorn"
    set(:unicorn_config) { "#{fetch :current_path}/config/unicorn.rb" }
    set(:unicorn_pid) { "#{fetch :shared_path}/tmp/pids/unicorn.pid" }
    set :unicorn_port, 8080

    task :start, :roles => :app, :except => { :no_release => true } do 
      run "cd #{fetch :current_path} && #{try_sudo} #{unicorn_binary} -c #{unicorn_config} -p #{unicorn_port} -E #{rails_env} -D"
    end
    task :stop, :roles => :app, :except => { :no_release => true } do 
      run "#{try_sudo} kill `cat #{unicorn_pid}`"
    end
    task :graceful_stop, :roles => :app, :except => { :no_release => true } do
      run "#{try_sudo} kill -s QUIT `cat #{unicorn_pid}`"
    end
    task :reload, :roles => :app, :except => { :no_release => true } do
      run "#{try_sudo} kill -s USR2 `cat #{unicorn_pid}`"
    end
    task :restart, :roles => :app, :except => { :no_release => true } do
      reload
      # stop
      # start
    end
  end
end
