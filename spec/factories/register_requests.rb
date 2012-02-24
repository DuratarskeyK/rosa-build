# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :register_request do
    name "MyString"
    email { Factory.next(:email) }
    token "MyString"
    interest "MyString"
    more "MyText"
    approved false
    rejected false
  end
end
