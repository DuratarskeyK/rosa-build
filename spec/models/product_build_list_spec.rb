# -*- encoding : utf-8 -*-
require 'spec_helper'

describe ProductBuildList do
  before(:all) do
    stub_symlink_methods
  end

  it { should belong_to(:product) }

  it { should ensure_length_of(:main_script).is_at_most(255) }
  it { should ensure_length_of(:params).is_at_most(255) }

  it { should validate_presence_of(:product_id)}
  it { should validate_presence_of(:status)}

  ProductBuildList::STATUSES.each do |value|
    it {should allow_value(value).for(:status)}
  end

  it {should_not allow_value(555).for(:status)}

  it { should have_readonly_attribute(:product_id) }
  #it { should_not allow_mass_assignment_of(:product_id) }

  it { should allow_mass_assignment_of(:status) }
  it { should allow_mass_assignment_of(:base_url) }

  # see app/ability.rb
  # can :read, ProductBuildList#, :product => {:platform => {:visibility => 'open'}} # double nested hash don't work
  it 'should generate correct sql to get product build lists' do
    stub_symlink_methods
    user = FactoryGirl.create(:user)
    ability = Ability.new user
    ProductBuildList.accessible_by(ability).count.should == 0
  end
end
