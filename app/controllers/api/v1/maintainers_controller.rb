class Api::V1::MaintainersController < Api::V1::BaseController
  before_filter :authenticate_user! unless APP_CONFIG['anonymous_access']
  load_and_authorize_resource :platform

  def index
    @maintainers = BuildList::Package.actual.by_platform(@platform)
                                     .includes(:project)
                                     .paginate(paginate_params)
  end
end
