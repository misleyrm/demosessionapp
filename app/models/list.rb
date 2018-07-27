class List < ApplicationRecord
  validates :name, presence: true
  attr_accessor :num_incompleted_tasks, :crop_x, :crop_y, :crop_w, :crop_h, :current_step
  has_attached_file :avatar,
  styles: { :medium => "200x200>", :thumb => "100x100>" }
  validates_attachment_content_type :avatar, :content_type => /^image\/(png|gif|jpeg|jpg)/

  mount_uploader :image, AvatarUploader
  after_save :crop_avatar, :if => lambda { |o| o.crop_x.present? || o.crop_y.present? || o.crop_w.present? || o.crop_h.present? }

  belongs_to :owner, class_name:"User", foreign_key:"user_id"

  # has_many :approved_comments, -> { where(approved: true) }, class_name: 'Comment'

  has_many :tasks
  has_many :users, through: :tasks, dependent: :destroy

  has_many :collaborations
  has_many :collaboration_users, through: :collaborations, :source => :user,dependent: :destroy

  has_many :invitations, dependent: :destroy

  # after_commit :broadcast_update, on: [:update]
  # after_create :broadcast_save
  after_destroy :broadcast_delete
  before_destroy :tasks_delete

  before_save :capitalize_name

  def crop_avatar
    image.recreate_versions! if crop_x.present?

  end

  # def skip_validation?
  #   skip_validation
  # end

  def owner_name
    self.owner.name
  end

  def collaborations?
    self.collaborations.count != 0
  end

  # Methods for set current list for access from model
  def self.current
    Thread.current[:list]
  end

  def self.current=(list)
    Thread.current[:list] = list
  end
  # END Methods for set current list for access from model
  def all_tasks_list?
    self.all_tasks
  end

  def avatar?
    !self.image_url.blank?
  end


  def pending_invitation
    self.invitations.where(["active!=?",true]).order('sent_at DESC')
  end

  def search_collaborators(id)
    users = self.collaboration_users

    array_owner = []
    array_owner.push(self.owner)
    collaborations = users + array_owner
    current = [User.find(id)]
    return collaborations - current
  end

  def broadcast_update

    if (self.previous_changes.key?(:user_id) &&
       self.previous_changes[:user_id].first != self.previous_changes[:user_id].last)
       user = User.find(self.user_id)
       ActionCable.server.broadcast "list:#{self.id}", htmlLi: render_list_li(self,user,false), htmlChip: render_list_chip(self), status: 'listUpdatedOwner', id: self.id, user: self.user_id, name: self.name, image: self.image_url(:thumb), before_owner: self.previous_changes[:user_id].first
    elsif !self.previous_changes.keys.nil?
      ActionCable.server.broadcast "list:#{self.id}", htmlChip: render_list_chip(self), status: 'listUpdated', id: self.id, user: self.user_id, name: self.name,  image: self.image_url(:thumb), allTask: self.all_tasks_list?
    end


    # if (self.previous_changes.key?(:list_id) &&
    #    self.previous_changes[:list_id].first != self.previous_changes[:list_id].last)
    #    status = 'changelist'
    #    num = self.user.num_incompleted_tasks(List.find(self.previous_changes[:list_id].first))
    #    num_list_change = self.user.num_incompleted_tasks(List.find(self.previous_changes[:list_id].last))
    #    ActionCable.server.broadcast 'list_channel', status: status, id: self.id, user: self.user_id, list_id: self.list_before, blocker: is_blocker?, list_change: self.list_id, num: num, num_list_change: num_list_change
    # elsif (self.previous_changes.key?(:completed_at) &&
    #     self.previous_changes[:completed_at].first != self.previous_changes[:completed_at].last) && (self.completed?)
    #     status = 'completed'
    #     num = self.user.num_incompleted_tasks(self.list)
    #     ActionCable.server.broadcast "list_channel", { html: render_task(self,partial),user: self.user_id, id: self.id, status: status,list_id: self.list_id, completed: self.completed?, partial: partial, blocker: is_blocker?, parentId: self.parent_task_id, num: num }
    # elsif self.previous_changes.key?(:flag) &&
    #        self.previous_changes[:flag].first != self.previous_changes[:flag].last
    #     ActionCable.server.broadcast 'list_channel', status: 'important', id: self.id, user: self.user_id, list_id: self.list_id, blocker: self.is_blocker?,important: self.flag
    # elsif self.previous_changes.key?(:deadline) &&
    #          self.previous_changes[:deadline].first != self.previous_changes[:deadline].last
    #      if (self.deadline?)
    #        ActionCable.server.broadcast 'list_channel', status: 'deadline', id: self.id, user: self.user_id, list_id: self.list_id, blocker: self.is_blocker?,deadline: self.deadline
    #      else
    #        ActionCable.server.broadcast 'list_channel', status: 'deletedeadline', id: self.id, user: self.user_id, list_id: self.list_id, blocker: self.is_blocker?,deadline: self.deadline
    #      end
    # else
    #    status = 'saved'
    #    ActionCable.server.broadcast "list_channel", { html: render_task(self,partial),user: user, id: self.id, status: status,list_id: list, completed: self.completed?, partial: partial, blocker: is_blocker?, parentId: self.parent_task_id, num: num }
    # end
  end

  def tasks_delete
    Notification.where(notifiable_id: self.id).delete_all
    Task.where(list_id: self.id).delete_all
  end

  # def broadcast_save
  #   data= Hash.new
  #   data["status"]= "created"
  #   data["id"]= self.id
  #   data["user"]= self.user_id
  #   data["name"]= self.name
  #
  #   # data["image"]= self.image_url(:thumb)
  #   data["allTask"]= self.all_tasks_list?
  #   ListRelayJob.perform_now(self,data)
  #
  #  end

  def broadcast_delete
    data= Hash.new
    data["status"]= "destroy"
    data["id"]= self.id
    data["user"]= self.user_id
    # data["current_user"]= self.user_id

    data["allTask_id"]= self.all_tasks_list?
    ListRelayJob.perform_now(self,data)
  end

  private

    def capitalize_name
      self.name = name.capitalize
    end

end
