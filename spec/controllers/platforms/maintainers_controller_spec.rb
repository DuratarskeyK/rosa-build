# -*- encoding : utf-8 -*-
require 'spec_helper'

shared_examples_for 'guest user' do

  it "should be able to view maintainers list(index)" do
    get :index, :platform_id => @platform.id
    response.should be_success
  end
end

describe Platforms::MaintainersController do
  before(:each) do
    stub_symlink_methods

    @platform = FactoryGirl.create(:platform)
    @user = FactoryGirl.create(:user)
    set_session_for(@user)
  end

  context 'for guest' do
    before {set_session_for(User.new)}

    # it_should_behave_like 'guest user'
    # it "should be able to view maintainers list(index)", :anonymous_access => true do
    #   get :index, :platform_id => @platform.id
    #   response.should be_success
    # end

    it "should not be able to view maintainers list(index)" do
      get :index, :platform_id => @platform.id
      response.should redirect_to(forbidden_path)
    end
  end

  context 'for global admin' do
    before(:each) do
      @user.role = "admin"
      @user.save
    end

    it_should_behave_like 'guest user'
  end

  context 'for registrated user' do

    it_should_behave_like 'guest user'
  end


  context 'for platform owner' do
    before(:each) do
      @user = @platform.owner
      set_session_for(@user)
    end

    it_should_behave_like 'guest user'
  end

  context 'for platform member' do
    before(:each) do
      @platform.relations.create!(:actor_type => 'User', :actor_id => @user.id, :role => 'admin')
    end

    it_should_behave_like 'guest user'
  end

end


