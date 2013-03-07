# -*- encoding : utf-8 -*-
module Grack
  class Auth < Base
    def initialize(app)
      @app = app
    end

    # TODO tests!!!
    def call(env)
      super
      if git?
        return render_not_found if project.blank?

        return ::Rack::Auth::Basic.new(@app) do |u, p|
          user = User.auth_by_token_or_login_pass(u, p) and
          ability = ::Ability.new(user) and ability.can?(action, project) and
          ENV['GL_ID'] = "user-#{user.id}"
        end.call(env) unless project.public? and read? # need auth
      end
      @app.call(env) # next app in stack
    end
  end
end
