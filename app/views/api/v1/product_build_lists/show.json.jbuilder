json.product_build_list do |json|
  json.partial! 'product_build_list', :product_build_list => @product_build_list, :json => json
  json.(@product_build_list, :commit_hash, :main_script, :params)

  json.product do |json_product|
    json.partial! 'api/v1/products/product',
      :product => @product_build_list.product, :json => json_product
  end

  json.project do |json_project|
    json.partial! 'api/v1/projects/project',
      :project => @product_build_list.project, :json => json_project
  end

  json.created_at @product_build_list.created_at.to_i
  json.updated_at @product_build_list.updated_at.to_i

  json.results (@product_build_list.results || []) do |json_logs, result|
    json_logs.file_name result['file_name']
    json_logs.size result['size']
    json_logs.url "#{APP_CONFIG['file_store_url']}/api/v1/file_stores/#{result['sha1']}"
  end
end
