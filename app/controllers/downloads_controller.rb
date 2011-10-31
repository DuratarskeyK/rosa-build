class DownloadsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :check_global_access

  def index
    @downloads = Download.paginate :page => params[:page], :per_page => 30
  end
  
  def refresh
    Download.rotate_nginx_log
    Download.send_later :parse_and_remove_nginx_log
    
    redirect_to downloads_path, :notice => t('flash.downloads.statistics_refreshed')
  end
end
