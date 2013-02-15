# -*- encoding : utf-8 -*-
require 'spec_helper'

describe Product do
  before(:all) do
    stub_symlink_methods
    Platform.delete_all
    User.delete_all
    Product.delete_all
    init_test_root
    # Need for validate_uniqueness_of check
    FactoryGirl.create(:product)
  end

  it { should belong_to(:platform) }
  it { should have_many(:product_build_lists)}

  it { should validate_presence_of(:name)}
  it { should validate_uniqueness_of(:name).scoped_to(:platform_id) }

  it { should ensure_length_of(:main_script).is_at_most(255) }
  it { should ensure_length_of(:params).is_at_most(255) }

  it { should have_readonly_attribute(:platform_id) }

  it { should_not allow_mass_assignment_of(:platform) }
  #it { should_not allow_mass_assignment_of(:platform_id) }
  it { should_not allow_mass_assignment_of(:product_build_lists) }

  after(:all) do
    Platform.delete_all
    User.delete_all
    Product.delete_all
    clear_test_root
  end

end
