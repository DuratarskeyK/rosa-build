# -*- encoding : utf-8 -*-
Factory.sequence :integer do |n|
  n
end

Factory.sequence :string do |n|
  "Lorem ipsum #{n}"
end

Factory.sequence :uname do |n|
  "test#{n}"
end

Factory.sequence :unixname do |n|
  "test_unixname#{n}"
end

Factory.sequence :email do |n|
  "email#{n}@example.com"
end

Factory.sequence :text do |n|
  "#{n}. Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
end

Factory.sequence :text_file do |n|
  stringio = StringIO.new("this is file content #{n}")
  stringio.instance_eval("def original_filename; 'stringio#{n}.txt'; end ")
  stringio
end
