# -*- encoding : utf-8 -*-
require 'spec_helper'

shared_examples_for 'show build list via api' do
  it 'should be able to perform show action' do
    get :show, @show_params
    response.should render_template("api/v1/build_lists/show")
  end

  it 'should be able to perform index action' do
    get :index, :format => :json
    response.should render_template("api/v1/build_lists/index")
  end
end

shared_examples_for 'not show build list via api' do
  it 'should not be able to perform show action' do
    get :show, @show_params
    response.body.should == {"message" => "Access violation to this page!"}.to_json
  end

  pending 'should not be able to perform index action' do
    get :index, :format => :json
    response.body.should == {"message" => "Access violation to this page!"}.to_json
  end
end

shared_examples_for 'create build list via api' do
  before {
    #@project.update_attributes({:repositories => @platform.repositories})
    #test_git_commit(@project)
  }

  it 'should create one more build list' do
    lambda { post :create, @create_params }.should change{ BuildList.count }.by(1)
  end

  it 'should return 200 response code' do
    post :create, @create_params
    response.should be_success
  end

  it 'should save correct commit_hash for branch based build' do
    post :create, @create_params
    #@project.build_lists.last.commit_hash.should == @project.repo.commits('master').last.id
    @project.build_lists.last.commit_hash.should == @params[:commit_hash]
  end

  it 'should save correct commit_hash for tag based build' do
    system("cd #{@project.repo.path} && git tag 4.7.5.3") # TODO REDO through grit
    post :create, @create_params
    #@project.build_lists.last.commit_hash.should == @project.repo.commits('4.7.5.3').last.id
    @project.build_lists.last.commit_hash.should == @params[:commit_hash]
  end

  it 'should not create without existing commit hash in project' do
    lambda{ post :create, @create_params.deep_merge(:build_list => {:commit_hash => 'wrong'})}.should change{@project.build_lists.count}.by(0)
  end
end

shared_examples_for 'not create build list via api' do
  before {
    #@project.update_attributes({:repositories => @platform.repositories})
    #test_git_commit(@project)
  }

  it 'should not be able to perform create action' do
    post :create, @create_params
    response.body.should == {"message" => "Access violation to this page!"}.to_json
  end

  it 'should not create one more build list' do
    lambda { post :create, @create_params }.should change{ BuildList.count }.by(0)
  end

  it 'should return 422 response code' do
    post :create, @create_params
    response.should_not be_success
  end
end

describe Api::V1::BuildListsController do
  before(:each) do
    stub_symlink_methods
    stub_redis
  end

  context 'create and update abilities' do
    context 'for user' do
      before(:each) do
        Arch.destroy_all
        User.destroy_all

        @build_list = FactoryGirl.create(:build_list_core)
        @params = @build_list.attributes.symbolize_keys
        @project = @build_list.project
        @platform = @build_list.save_to_platform
        #@platform = FactoryGirl.create(:platform_with_repos)

        stub_symlink_methods
        @user = FactoryGirl.create(:user)
        @owner_user = @project.owner
        @member_user = FactoryGirl.create(:user)
        @project.relations.create(:role => 'reader', :actor => @member_user)
        @build_list.save_to_platform.relations.create(:role => 'admin', :actor => @owner_user) # Why it's really need it??

        # Create and show params:
        @create_params = {:build_list => @build_list.attributes.symbolize_keys.except(:bs_id)
                           .merge(:qwerty=>'!')} # wrong parameter
        @create_params = @create_params.merge(:arches => [@params[:arch_id]], :build_for_platforms => [@params[:build_for_platform_id]], :format => :json)
        any_instance_of(Project, :versions => ['v1.0', 'v2.0'])

        http_login(@user)
      end

      context "do cancel" do
        def do_cancel
          put :cancel, :id => @build_list, :format => :json
        end

        context 'if user is project owner' do
          before(:each) {http_login(@owner_user)}

          context "if it has :build_pending status" do
            before do
              @build_list.update_column(:status, BuildList::BUILD_PENDING)
              do_cancel
            end

            it "should return correct json message" do
              response.body.should == { :build_list => {:id => @build_list.id, :message => I18n.t('layout.build_lists.cancel_success')} }.to_json
            end

            it 'should return 200 response code' do
              response.should be_success
            end

            it "should cancel build list" do
              @build_list.reload.status.should == BuildList::BUILD_CANCELING
            end
          end

          context "if it has another status" do
            before do
              @build_list.update_column(:status, BuildList::PROJECT_VERSION_NOT_FOUND)
              do_cancel
            end

            it "should return correct json error message" do
              response.body.should == { :build_list => {:id => nil, :message => I18n.t('layout.build_lists.cancel_fail')} }.to_json
            end

            it 'should return 422 response code' do
              response.should_not be_success
            end

            it "should not cancel build list" do
              @build_list.reload.status.should == BuildList::PROJECT_VERSION_NOT_FOUND
            end
          end
        end

        context 'if user is not project owner' do
          before(:each) do
            @build_list.update_column(:status, BuildList::BUILD_PENDING)
            do_cancel
          end

          it "should return access violation message" do
            response.body.should == {"message" => "Access violation to this page!"}.to_json
          end

          it "should not cancel build list" do
            @build_list.reload.status.should == BuildList::BUILD_PENDING
          end
        end
      end

      context "do publish" do
        def do_publish
          put :publish, :id => @build_list, :format => :json
        end

        context 'if user is project owner' do
          before(:each) do
            http_login(@owner_user)
            @build_list.update_column(:status, BuildList::FAILED_PUBLISH)
            do_publish
          end

          context "if it has :failed_publish status" do
            it "should return correct json message" do
              response.body.should == { :build_list => {:id => @build_list.id, :message => I18n.t('layout.build_lists.publish_success')} }.to_json
            end

            it 'should return 200 response code' do
              response.should be_success
            end

            it "should cancel build list" do
              @build_list.reload.status.should == BuildList::BUILD_PUBLISH
            end
          end

          context "if it has another status" do
            before(:each) do
              @build_list.update_column(:status, BuildList::PROJECT_VERSION_NOT_FOUND)
              do_publish
            end

            it "should return correct json error message" do
              response.body.should == { :build_list => {:id => nil, :message => I18n.t('layout.build_lists.publish_fail')} }.to_json
            end

            it 'should return 422 response code' do
              response.should_not be_success
            end

            it "should not cancel build list" do
              @build_list.reload.status.should == BuildList::PROJECT_VERSION_NOT_FOUND
            end
          end
        end

        context 'if user is not project owner' do
          before(:each) do
            @build_list.update_column(:status, BuildList::FAILED_PUBLISH)
            do_publish
          end

          it "should return access violation message" do
            response.body.should == {"message" => "Access violation to this page!"}.to_json
          end

          it "should not cancel build list" do
            @build_list.reload.status.should == BuildList::FAILED_PUBLISH
          end
        end
      end

      context "do reject_publish" do
        before(:each) do
          any_instance_of(BuildList, :current_duration => 100)
          @build_list.save_to_repository.update_column(:publish_without_qa, false)
        end

        def do_reject_publish
          put :reject_publish, :id => @build_list, :format => :json
        end

        context 'if user is project owner' do
          before(:each) do
            http_login(@owner_user)
            @build_list.update_column(:status, BuildList::SUCCESS)
            @build_list.save_to_platform.update_column(:released, true)
            do_reject_publish
          end

          context "if it has :success status" do
            it "should return correct json message" do
              response.body.should == { :build_list => {:id => @build_list.id, :message => I18n.t('layout.build_lists.reject_publish_success')} }.to_json
            end

            it 'should return 200 response code' do
              response.should be_success
            end

            it "should reject publish build list" do
              @build_list.reload.status.should == BuildList::REJECTED_PUBLISH
            end
          end

          context "if it has another status" do
            before(:each) do
              @build_list.update_column(:status, BuildList::PROJECT_VERSION_NOT_FOUND)
              do_reject_publish
            end

            it "should return correct json error message" do
              response.body.should == { :build_list => {:id => nil, :message => I18n.t('layout.build_lists.reject_publish_fail')} }.to_json
            end

            it 'should return 422 response code' do
              response.should_not be_success
            end

            it "should not cancel build list" do
              @build_list.reload.status.should == BuildList::PROJECT_VERSION_NOT_FOUND
            end
          end
        end

        context 'if user is not project owner' do
          before(:each) do
            @build_list.update_column(:status, BuildList::SUCCESS)
            @build_list.save_to_platform.update_column(:released, true)
            do_reject_publish
          end

          it "should return access violation message" do
            response.body.should == {"message" => "Access violation to this page!"}.to_json
          end

          it "should not cancel build list" do
            do_reject_publish
            @build_list.reload.status.should == BuildList::SUCCESS
          end
        end
      end

      context 'for open project' do
        it_should_behave_like 'not create build list via api'

        context 'if user is project owner' do
          before(:each) {http_login(@owner_user)}
          it_should_behave_like 'create build list via api'
        end

        context 'if user is project read member' do
          before(:each) {http_login(@member_user)}
        end
      end

      context 'for hidden project' do
        before(:each) do
          @project.update_column(:visibility, 'hidden')
        end

        it_should_behave_like 'not create build list via api'

        context 'if user is project owner' do
          before(:each) {http_login(@owner_user)}

          it_should_behave_like 'create build list via api'
        end

        context 'if user is project read member' do
          before(:each) {http_login(@member_user)}
          it_should_behave_like 'not create build list via api'
        end
      end
    end

    context 'for group' do
      before(:each) do
        Arch.destroy_all
        User.destroy_all

        @build_list = FactoryGirl.create(:build_list_core)
        @params = @build_list.attributes.symbolize_keys
        @project = @build_list.project
        @platform = @build_list.save_to_platform

        stub_symlink_methods
        @user = FactoryGirl.create(:user)
        @owner_user = FactoryGirl.create(:user)
        @member_user = FactoryGirl.create(:user)

        # Create and show params:
        @create_params = {:build_list => @build_list.attributes.symbolize_keys.except(:bs_id)}
        @create_params = @create_params.merge(:arches => [@params[:arch_id]], :build_for_platforms => [@params[:build_for_platform_id]], :format => :json)
        any_instance_of(Project, :versions => ['v1.0', 'v2.0'])

        # Groups:
        @owner_group = FactoryGirl.create(:group, :owner => @owner_user)
        @member_group = FactoryGirl.create(:group)
        @member_group.actors.create :role => 'reader', :actor_id => @member_user.id, :actor_type => 'User'

        @group = FactoryGirl.create(:group)
        @user = FactoryGirl.create(:user)
        @group.actors.create :role => 'reader', :actor_id => @user.id, :actor_type => 'User'

        @project.owner = @owner_group
        @project.save

        @project.relations.create :role => 'reader', :actor_id => @member_group.id, :actor_type => 'Group'
        @project.relations.create :role => 'admin', :actor_id => @owner_group.id, :actor_type => 'Group'
        @build_list.save_to_platform.relations.create(:role => 'admin', :actor => @owner_group) # Why it's really need it??
        @build_list.save_to_platform.relations.create(:role => 'reader', :actor => @member_group) # Why it's really need it??

        http_login(@user)
      end

      context 'for open project' do
        it_should_behave_like 'not create build list via api'

        context 'if user is group owner' do
          before(:each) {http_login(@owner_user)}
          it_should_behave_like 'create build list via api'
        end

        context 'if user is group read member' do
          before(:each) {http_login(@member_user)}
          it_should_behave_like 'not create build list via api'
        end
      end

      context 'for hidden project' do
        before(:each) do
          @build_list.project.update_column(:visibility, 'hidden')
        end

        it_should_behave_like 'not create build list via api'

        context 'if user is group owner' do
          before(:each) {http_login(@owner_user)}
          it_should_behave_like 'create build list via api'
        end

        context 'if user is group read member' do
          before(:each) {http_login(@member_user)}
          it_should_behave_like 'not create build list via api'
        end
      end

    end
  end

  context 'read and accessible abilities' do
    before(:each) do
      Arch.destroy_all
      User.destroy_all

      @user = FactoryGirl.create(:user)

      # Build Lists:
      @build_list1 = FactoryGirl.create(:build_list_core)

      @build_list2 = FactoryGirl.create(:build_list_core)
      @build_list2.project.update_column(:visibility, 'hidden')

      project = FactoryGirl.create(:project_with_commit, :visibility => 'hidden', :owner => @user)
      @build_list3 = FactoryGirl.create(:build_list_core_with_attaching_project, :project => project)

      @build_list4 = FactoryGirl.create(:build_list_core)
      @build_list4.project.update_column(:visibility, 'hidden')
      @build_list4.project.relations.create! :role => 'reader', :actor_id => @user.id, :actor_type => 'User'

      @filter_build_list1 = FactoryGirl.create(:build_list_core)
      @filter_build_list2 = FactoryGirl.create(:build_list_core)
      @filter_build_list3 = FactoryGirl.create(:build_list_core)
      @filter_build_list4 = FactoryGirl.create(:build_list_core, :updated_at => (Time.now - 1.day),
                             :project => @build_list3.project, :save_to_platform => @build_list3.save_to_platform,
                             :arch => @build_list3.arch)
    end

    context 'for guest' do
      it 'should be able to perform index action', :anonymous_access => true do
        get :index, :format => :json
        response.should be_success
      end

      it 'should not be able to perform index action', :anonymous_access => false do
        get :index, :format => :json
        response.status.should == 401
      end
    end

    context 'for all build lists' do
      before(:each) {
        http_login(@user)
      }

      it 'should be able to perform index action' do
        get :index, :format => :json
        response.should be_success
      end

      it 'should show only accessible build_lists' do
        get :index, :filter => {:ownership => 'index'}, :format => :json
        assigns(:build_lists).should include(@build_list1)
        assigns(:build_lists).should_not include(@build_list2)
        assigns(:build_lists).should include(@build_list3)
        assigns(:build_lists).should include(@build_list4)
        assigns(:build_lists).count.should eq 7
      end
    end

    context 'filter' do
      before(:each) do
        http_login FactoryGirl.create(:admin)
      end

      it 'should filter by bs_id' do
        get :index, :filter => {:bs_id => @filter_build_list1.bs_id, :project_name => 'fdsfdf', :any_other_field => 'do not matter'}, :format => :json
        assigns[:build_lists].should include(@filter_build_list1)
        assigns[:build_lists].should_not include(@filter_build_list2)
        assigns[:build_lists].should_not include(@filter_build_list3)
      end

      it 'should filter by project_name' do
        get :index, :filter => {:project_name => @filter_build_list2.project.name, :ownership => 'index'}, :format => :json
        assigns[:build_lists].should_not include(@filter_build_list1)
        assigns[:build_lists].should include(@filter_build_list2)
        assigns[:build_lists].should_not include(@filter_build_list3)
      end

      it 'should filter by project_name and start_date' do
        get :index, :filter => {:project_name => @filter_build_list3.project.name, :ownership => 'index',
                              :"updated_at_start(1i)" => @filter_build_list3.updated_at.year.to_s,
                              :"updated_at_start(2i)" => @filter_build_list3.updated_at.month.to_s,
                              :"updated_at_start(3i)" => @filter_build_list3.updated_at.day.to_s}, :format => :json
        assigns[:build_lists].should_not include(@filter_build_list1)
        assigns[:build_lists].should_not include(@filter_build_list2)
        assigns[:build_lists].should include(@filter_build_list3)
        assigns[:build_lists].should_not include(@filter_build_list4)
      end

    end

    context "for user" do
      before(:each) do
        @build_list = FactoryGirl.create(:build_list_core)
        @params = @build_list.attributes.symbolize_keys
        @project = @build_list.project

        stub_symlink_methods
        @owner_user = @project.owner
        @member_user = FactoryGirl.create(:user)
        @project.relations.create(:role => 'reader', :actor => @member_user)
        @build_list.save_to_platform.relations.create(:role => 'admin', :actor => @owner_user) # Why it's really need it??

        # Show params:
        @show_params = {:id => @build_list.id, :format => :json}
      end

      context 'for open project' do
        context 'for simple user' do
          before(:each) {http_login(@user)}
          it_should_behave_like 'show build list via api'
        end

        context 'if user is project owner' do
          before(:each) {http_login(@owner_user)}
          it_should_behave_like 'show build list via api'
        end

        context 'if user is project read member' do
          before(:each) {http_login(@member_user)}
          it_should_behave_like 'show build list via api'
        end
      end

      context 'for hidden project' do
        before(:each) do
          @project.update_column(:visibility, 'hidden')
        end

        context 'for simple user' do
          before(:each) {http_login(@user)}
          it_should_behave_like 'not show build list via api'
        end

        context 'if user is project owner' do
          before(:each) {http_login(@owner_user)}
          it_should_behave_like 'show build list via api'
        end

        context 'if user is project read member' do
          before(:each) {http_login(@member_user)}
          it_should_behave_like 'show build list via api'
        end
      end
    end

    context "for group" do
      before(:each) do
        @platform = FactoryGirl.create(:platform_with_repos)
        @build_list = FactoryGirl.create(:build_list_core, :save_to_platform => @platform)
        @project = @build_list.project
        @params = @build_list.attributes.symbolize_keys

        stub_symlink_methods
        @owner_user = @project.owner#FactoryGirl.create(:user)
        @member_user = FactoryGirl.create(:user)
        #@project.relations.create(:role => 'reader', :actor => @member_user)

        # Show params:
        @show_params = {:id => @build_list.id, :format => :json}

        # Groups:
        @owner_group = FactoryGirl.create(:group, :owner => @owner_user)
        @member_group = FactoryGirl.create(:group)
        @member_group.actors.create :role => 'reader', :actor_id => @member_user.id, :actor_type => 'User'
        @group = FactoryGirl.create(:group)
        @group.actors.create :role => 'reader', :actor_id => @user.id, :actor_type => 'User'

        #@project = FactoryGirl.create(:project, :owner => @owner_group, :repositories => @platform.repositories)

        #@project.owner = @owner_group
        #@project.save
        @project.relations.create :role => 'reader', :actor_id => @member_group.id, :actor_type => 'Group'
        #@build_list.save_to_platform.relations.create(:role => 'reader', :actor => @member_group) # Why it's really need it??
        #@build_list.save_to_platform.relations.create(:role => 'admin', :actor => @owner_group) # Why it's really need it??
      end

      context 'for open project' do
        context 'for simple user' do
          before(:each) {http_login(@user)}
          it_should_behave_like 'show build list via api'
        end

        context 'if user is group owner' do
          before(:each) {http_login(@owner_user)}
          it_should_behave_like 'show build list via api'
        end

        context 'if user is group read member' do
          before(:each) {http_login(@member_user)}
          it_should_behave_like 'show build list via api'
        end
      end

      context 'for hidden project' do
        before(:each) do
          @build_list.project.update_column(:visibility, 'hidden')
        end

        context 'for simple user' do
          before(:each) {http_login(@user)}
          it_should_behave_like 'not show build list via api'
        end

        context 'if user is group owner' do
          before(:each) { http_login(@owner_user) }
          it_should_behave_like 'show build list via api'
        end

        context 'if user is group read member' do
          before(:each) {http_login(@member_user)}
          it_should_behave_like 'show build list via api'
        end
      end
    end

  end
end
