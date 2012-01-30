class User < ActiveRecord::Base
  ROLES = ['admin']
  LANGUAGES_FOR_SELECT = [['Russian', 'ru'], ['English', 'en']]
  LANGUAGES = LANGUAGES_FOR_SELECT.map(&:last)

  devise :database_authenticatable, :registerable, :omniauthable, # :token_authenticatable, :encryptable, :timeoutable
         :recoverable, :rememberable, :validatable #, :trackable, :confirmable, :lockable

  has_one :notifier, :class_name => 'Settings::Notifier' #:notifier

  has_many :authentications, :dependent => :destroy
  has_many :build_lists, :dependent => :destroy

  has_many :relations, :as => :object, :dependent => :destroy
  has_many :targets, :as => :object, :class_name => 'Relation'

  has_many :own_projects, :as => :owner, :class_name => 'Project', :dependent => :destroy
  has_many :own_groups,   :foreign_key => :owner_id, :class_name => 'Group'
  has_many :own_platforms, :as => :owner, :class_name => 'Platform', :dependent => :destroy
  has_many :own_repositories, :as => :owner, :class_name => 'Repository', :dependent => :destroy

  has_many :groups,       :through => :targets, :source => :target, :source_type => 'Group',      :autosave => true
  has_many :projects,     :through => :targets, :source => :target, :source_type => 'Project',    :autosave => true
  has_many :platforms,    :through => :targets, :source => :target, :source_type => 'Platform',   :autosave => true
  has_many :repositories, :through => :targets, :source => :target, :source_type => 'Repository', :autosave => true
  has_many :subscribes, :foreign_key => :user_id, :dependent => :destroy

  has_many :comments, :dependent => :destroy
  has_many :emails, :class_name => 'UserEmail', :dependent => :destroy

  include Modules::Models::PersonalRepository

  validates :uname, :presence => true, :uniqueness => {:case_sensitive => false}, :format => { :with => /^[a-z0-9_]+$/ }
  validate { errors.add(:uname, :taken) if Group.where('uname LIKE ?', uname).present? }
  validates :ssh_key, :uniqueness => true, :allow_blank => true
  validates :role, :inclusion => {:in => ROLES}, :allow_blank => true
  validates :language, :inclusion => {:in => LANGUAGES}, :allow_blank => true

  attr_accessible :email, :password, :password_confirmation, :remember_me, :login, :name, :ssh_key, :uname, :language
  attr_readonly :uname
  attr_accessor :login

  accepts_nested_attributes_for :emails, :allow_destroy => true

  after_create :create_settings_notifier
  after_create :add_user_email

  def admin?
    role == 'admin'
  end

  def guest?
    self.id.blank? # persisted?
  end

  def fullname
    return "#{uname} (#{name})"
  end
  class << self
    def find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      login = conditions.delete(:login)
      where(conditions).where("lower(uname) = :value OR " +
        "exists (select null from user_emails m where m.user_id = m.user_id and lower(m.email) = :value)",
        {:value => login.downcase}).first
    end

    def new_with_session(params, session)
      super.tap do |user|
        if data = session["devise.omniauth_data"]
          if info = data['info'] and info.present?
            user.email = info['email'].presence if user.email.blank?
            user.uname ||= info['nickname'].presence || info['username'].presence
            user.name ||= info['name'].presence || [info['first_name'], info['last_name']].join(' ').strip
          end
          user.password = Devise.friendly_token[0,20] # stub password
          user.authentications.build :uid => data['uid'], :provider => data['provider']
        end
      end
    end
  end

  def update_with_password(params={})
    params.delete(:current_password)
    # self.update_without_password(params) # Don't allow password update
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end
    result = update_attributes(params)
    clean_up_passwords
    result
  end

  def commentor?(commentable)
    comments.exists?(:commentable_type => commentable.class.name, :commentable_id => commentable.id)
  end

  def committer?(commit)
    emails.exists? :email_lower => commit.committer.email.downcase
  end

  private

  def create_settings_notifier
    self.create_notifier
  end

  def add_user_email
    UserEmail.create(:user_id => self.id, :email => self.email)
  end
end
