# -*- encoding : utf-8 -*-
base_path  = "/srv/rosa_build"
pidfile File.join(base_path, 'shared', 'pids', 'unicorn.pid')
state_path File.join(base_path, 'shared', 'pids', 'puma.state')
bind 'unix:///tmp/rosa_build_unicorn.sock'

environment ENV['RAILS_ENV'] || 'production'
threads *(ENV['PUMA_THREADS'] || '1,4').split(',')
workers ENV['PUMA_WORKERS'] || 7


preload_app!

on_worker_boot do
  if defined?(ActiveRecord::Base)
    ActiveSupport.on_load(:active_record) do
      ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
      ActiveRecord::Base.establish_connection
    end
    # QC::Conn.connect
    Rails.logger.info('Connected to PG')
  end

  # Redis.connect!
  # Rails.logger.info('Connected to Redis')
end

activate_control_app 'unix:///tmp/rosa_build_pumactl.sock'