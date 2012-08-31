# -*- encoding : utf-8 -*-
require 'spec_helper'

shared_examples_for 'admin user' do

  it 'should be able to create product' do
    lambda { post :create, @create_params }.should change{ Product.count }.by(1)
    response.should redirect_to(platform_product_path( Product.last.platform.id, Product.last ))
  end

  it 'should be able to update product' do
    put :update, {:id => @product.id}.merge(@update_params)
    response.should redirect_to platform_product_path(@platform, @product)
    @product.reload
    @product.name.should eql('pro2')
  end

  it 'should be able to destroy product' do
    lambda { delete :destroy, :id => @product.id, :platform_id => @platform }.should change{ Product.count }.by(-1)
    response.should redirect_to(platform_products_path(@platform))
  end

end

describe Platforms::ProductsController do
	before(:each) do
    stub_symlink_methods

    @another_user = FactoryGirl.create(:user)
    @platform = FactoryGirl.create(:platform)
    @product = FactoryGirl.create(:product, :platform => @platform)
    @create_params = {:product => {:name => 'pro'}, :platform_id => @platform.id}
    @update_params = {:product => {:name => 'pro2'}, :platform_id => @platform.id}
	end

  context 'for guest' do
    [:create].each do |action|
      it "should not be able to perform #{ action } action" do
        get action, :platform_id => @platform.id
        response.should redirect_to(new_user_session_path)
      end
    end

    [:new, :edit, :update, :destroy].each do |action|
      it "should not be able to perform #{ action } action" do
        get action, :id => @product.id, :platform_id => @platform.id
        response.should redirect_to(new_user_session_path)
      end
    end

    if APP_CONFIG['anonymous_access']
      it "should be able to perform show action" do
        get :show, :id => @product.id, :platform_id => @platform.id
        response.should render_template(:show)
      end
    else
      it "should not be able to perform show action" do
        get :show, :id => @product.id, :platform_id => @platform.id
        response.should redirect_to(new_user_session_path)
      end
    end
  end

  context 'for global admin' do
    before(:each) do
      @admin = FactoryGirl.create(:admin)
      set_session_for(@admin)
    end

    it_should_behave_like 'admin user'
  end



  context 'for admin relation user' do
    before(:each) do
      @user = FactoryGirl.create(:user)
      set_session_for(@user)
      @platform.relations.create!(:actor_type => 'User', :actor_id => @user.id, :role => 'admin')
    end

    it_should_behave_like 'admin user'
  end

  context 'for no relation user' do
    before(:each) do
      @user = FactoryGirl.create(:user)
      set_session_for(@user)
    end

    it 'should not be able to create product' do
      lambda { post :create, @create_params }.should change{ Product.count }.by(0)
      response.should redirect_to(forbidden_path)
    end

    it 'should not be able to perform update action' do
      put :update, {:id => @product.id}.merge(@update_params)
      response.should redirect_to(forbidden_path)
    end

    it 'should not be able to destroy product' do
      lambda { delete :destroy, :id => @product.id, :platform_id => @platform }.should change{ Product.count }.by(0)
      response.should redirect_to(forbidden_path)
    end

  end

end
