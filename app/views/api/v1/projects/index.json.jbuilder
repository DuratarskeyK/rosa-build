json.projects @projects do |project|
  json.partial! 'project', :project => project
  json.(project, :visibility, :description, :ancestry, :has_issues, :has_wiki, :default_branch, :is_package, :average_build_time, :publish_i686_into_x86_64)
  json.created_at project.created_at.to_i
  json.updated_at project.updated_at.to_i
  json.partial! 'api/v1/shared/owner', :owner => project.owner
end

json.url api_v1_projects_path(:format => :json)