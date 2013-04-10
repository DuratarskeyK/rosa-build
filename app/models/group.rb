# -*- encoding : utf-8 -*-
class Group < Avatar
  belongs_to :owner, :class_name => 'User'

  has_many :relations, :as => :actor, :dependent => :destroy, :dependent => :destroy
  has_many :actors, :as => :target, :class_name => 'Relation', :dependent => :destroy
  has_many :targets, :as => :actor, :class_name => 'Relation', :dependent => :destroy

  has_many :members,  :through => :actors,  :source => :actor,  :source_type => 'User',    :autosave => true
  has_many :projects, :through => :targets, :source => :target, :source_type => 'Project', :autosave => true

  has_many :own_projects, :as => :owner, :class_name => 'Project', :dependent => :destroy
  has_many :own_platforms, :as => :owner, :class_name => 'Platform', :dependent => :destroy

  validates :owner, :presence => true
  validates :uname, :presence => true, :uniqueness => {:case_sensitive => false}, :format => {:with => /\A[a-z0-9_]+\z/}, :reserved_name => true
  validate { errors.add(:uname, :taken) if User.by_uname(uname).present? }

  scope :opened, where('1=1')
  scope :by_owner, lambda {|owner| where(:owner_id => owner.id)}
  scope :by_admin, lambda {|admin| joins(:actors).where(:'relations.role' => 'admin', :'relations.actor_id' => admin.id, :'relations.actor_type' => 'User')}

  attr_accessible :uname, :description
  attr_readonly :uname

  delegate :email, :to => :owner

  after_create :add_owner_to_members

  include Modules::Models::ActsLikeMember
  include Modules::Models::PersonalRepository
  # include Modules::Models::Owner

  def self.can_own_project(user)
    (by_owner(user) | by_admin(user))
  end

  def name
    uname
  end

  def add_member(member, role = 'admin')
    Relation.add_member(member, self, role, :actors)
  end

  def remove_member(member)
    Relation.remove_member(member, self)
  end

  def system?
    false
  end

  def fullname
    return description.present? ? "#{uname} (#{description})" : uname
  end

  protected

  def add_owner_to_members
    Relation.create_with_role(self.owner, self, 'admin') # members << self.owner if !members.exists?(:id => self.owner.id)
  end
end
