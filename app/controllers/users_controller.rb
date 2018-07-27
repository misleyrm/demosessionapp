class UsersController < ApplicationController
  include UsersHelper
  include ApplicationHelper
  before_action :require_logged_in, only: [:index,:show, :edit, :update, :destroy]
  before_action :set_user, only: [:show, :update, :updateAvatar, :list_user, :destroy, :updateEmail, :updatePassword, :settings, :crop,:setCoord, :notifications]
  attr_accessor :email, :name, :password, :password_confirmation, :image
  skip_before_action :verify_authenticity_token
  before_action :set_list, if: -> { !params[:type].blank? && params[:type]=="collaborator"}
  before_action :set_active_all_collaborations, only: [:index], if: -> { !params[:type].blank? && params[:type]=="collaborator"}
  before_action :set_active_collaborations, only: [:show], if: -> { !params[:type].blank? && params[:type]=="collaborator"}
  # before_action :validate_email_update, only: :updateEmail
  # before_action :validate_update, only: :update
  before_action :validate_password_update, only: :updatePassword

  def index
    # @users = current_list.select(:id).collaboration_users.where.not(id: current_user.id)
    respond_to do |format|
      format.json { render json: @active_collaborations }
      format.js
    end

  end

  def roleUpdate
    this_user = User.find(session[:user_id])
    authorize this_user
    user_id = params[:user_id]
    new_role = params[:new_role]
    update_this_user = User.find(user_id)
    update_this_user.update(role: new_role)
  end


  def show
    respond_to do |format|
      format.html {redirect_to root_path}
      format.json { render json: @user }
      format.js
    end
  end

  def new
    # user = User.find(session[:user_id])
    # authorize user
    @user = User.new
    @token = params[:invitation_token]
    if !@token.nil? && !Invitation.find_by_token(@token).blank?
      @user.email = Invitation.find_by_token(@token).recipient_email
    elsif !@token.nil? && Invitation.find_by_token(@token).blank?
      flash[:danger]= "The invitations was revoke"
    end

  end

  # def set_task_per_user
  #   byebug
  #   d_today = get_current_date
  #   d_yesterday =  d_today - 1.day
  #   incomplete_tasks = @list.incompleted_tasks(@user)
  #   @incomplete_tasks = incomplete_tasks.where(["DATE(created_at)=?",d_today])
  #   byebug
  #   @incomplete_tasks_past= (Date.today == d_today)? incomplete_tasks - @incomplete_tasks : nil
  #   # @incomplete_tasks_past = incomplete_tasks - @incomplete_tasks
  #   # @list.incompleted_tasks(@user).where(["DATE(created_at)<?",d_today])
  #   # @incomplete_tasks = @tasks.where(["completed_at IS ? and DATE(created_at)=?",nil,d_today])
  #   @complete_tasks = @list.completed_tasks(@user).where('DATE(completed_at) BETWEEN ? AND ?' , d_yesterday , d_today ).order('completed_at')
  # end

  def edit
    # authorize @user
    @user = User.find(params[:id])
    @pending_invitations = @user.pending_invitations
    @accepted_invitations = @user.accepted_invitations
    @notification_options = NotificationOption.all.order(id: :asc)
    @notification = @user.notification_setting_texts
    respond_to do |format|
      format.html { }
      format.json { render json: @user}
      format.js { }
    end

  end

  def settings
    render layout: 'modal'
  end

  def notifications
    @notification_options = NotificationOption.all.order(id: :asc)
    @notification = @user.notification_setting_texts
    render layout: 'modal'
  end

  def showCompletedTask
    @user = User.find(params[:id])
    gon.behavior = @behavior = params[:behavior]
    @current_date = current_date
    @list = current_list
    respond_to do |format|
      format.html { }
      format.json {  }
      format.js { }
    end

  end

  def create

    if (@user = User.find_by_email(user_params[:email]))
      flash[:danger] = "We found an account under that email. Please login or reset your password."
      redirect_to password_resets_path
    else
      @user = User.create(user_params)
      @token = params[:invitation_token]
      if @user.save
        if !@token.nil? && !Invitation.find_by_token(@token).blank?
            @invitation = Invitation.find_by_token(@token)
            @list = @invitation.list #find the list_id attached to the invitation

            unless @user.collaboration_lists.include?(@list)
               hasCollaborationsList = @user.collaboration_lists.count > 0 ? true : false
               @user.collaboration_lists.push(@list)  #add this user to the list as a collaborator
               @invitation.update_attributes(:active => true)
               htmlCollaborationUser = ListsController.render(partial: "lists/collaboration_user", locals: {"collaboration_user": @user, "current_list": @list, "active_users": "","current_user": @user}).squish
               htmlInvitationSetting = ListsController.render(partial: "lists/list_pending_invitation", locals: { "pending_invitation": @invitation, "list": @list }).squish
               htmlListMembersSettings = ListsController.render(partial: "lists/edit/list_members", locals: {"list": @list, "member": @user }).squish
               htmlCollaborationsList = ""
               ActionCable.server.broadcast "invitation_channel", status: 'activated',id: @invitation.id,  htmlCollaborationUser:  htmlCollaborationUser,htmlInvitationSetting: htmlInvitationSetting, htmlListMembersSettings: htmlListMembersSettings, owner: @list.owner.id, sender:@invitation.sender_id, recipient: @invitation.recipient_id, list_id: @list.id, htmlCollaborationsList: htmlCollaborationsList, hasCollaborationsList: hasCollaborationsList
            end
            @collaboration = Collaboration.find_by(list_id: @list.id,user_id: @user.id)
            @collaboration.update_attributes(:collaboration_date => Time.now)
        end
        @user.send_activation_email
        # UserMailer.account_activation(@user).deliver_now
        # Please check your email to activate your account.

        flash[:success] = "A message with a confirmation link has been sent to your email address. Please follow the link to activate your account."
        redirect_to confirmation_page_path

      else
        render 'new', layout: "login"
      end
    end
  end

  def crop
    render layout: 'popupcrop'
  end

  def setCoord
    @user.crop_x = user_params[:crop_x]  #params[:user][:crop_x]
    @user.crop_y = user_params[:crop_y] #params[:user][:crop_y]
    @user.crop_w = user_params[:crop_w] #params[:user][:crop_w]
    @user.crop_h = user_params[:crop_h] #params[:user][:crop_h]
    if @user.save!
      respond_to do |format|
        flash[:notice] = "Avatar updated"
        # format.html {  }
        format.js {  }
      end
    end
  end

  def update
    # if validate_update

        if !user_params[:new_email].blank?
          @user.current_step = 'email'
          @user.current_password = user_params[:current_password]
          @user.email_confirmation = user_params[:new_email_confirmation]
          if @user && @user.authenticate(user_params[:current_password]) && @user.activated
            if @user.update_attributes(:first_name => user_params[:first_name],:last_name => user_params[:last_name], :email => user_params[:new_email])
              flash[:notice] = "First name, last name and email were updated"
              respond_to do |format|
                format.html {  }
                format.js {  }
              end
            else
              render :edit => {:status => 'fail',  :errors => @user.errors.full_messages}
            end
          else
            @user.errors.add(:password, :incorrect,message: "is not correct.")
            render :edit => {:status => 'fail',  :errors => @user.errors.full_messages}
          end
        else
          if @user.update_attributes(:first_name => user_params[:first_name],:last_name => user_params[:last_name]) #@user.update_attributes(:first_name => user_params[:first_name],:last_name => user_params[:last_name], :email => user_params[:new_email]) #@user.update_attributes(user_params)
            flash[:notice] = "First name and last name were updated"
            respond_to do |format|
              format.html {  }
              format.js {  }
            end
          else
             render :edit => {:status => 'fail',  :errors => @user.errors.full_messages}
          end
        end


    # end
      # else
      #    render :edit => {:status => 'fail',  :errors => @user.errors.full_messages}
      # end


  end

  def updateAvatar
    if user_params[:image].present?
      @user.current_step = 'avatar'
      if @user.update_attributes(image: user_params[:image])
        flash[:notice] = "Avatar updated"
        # respond_to do |format|
        #   format.html { }
        #   format.js { render 'crop' }
        # end
        render 'crop'
      end
    else
      render :json => {:status => 'fail', :errors => @user.errors.full_messages,:email => @user.email}
    end

  end


  # def updateEmail
  #   # if resource.email != params[:email] || params[:password].present?
  #   @user.current_step = (user_params[:current_step].present?)? user_params[:current_step] : ""
  #   gon.current_step = @user.current_step
  #   if @user && @user.authenticate(user_params[:current_password]) && @user.activated
  #       if @user.update_attributes(:email => user_params[:new_email])
  #         flash[:notice] = "Email updated"
  #         render :json => {:status => 'success', :email => @user.email}
  #       else
  #         render :edit => {:status => 'fail',  :errors => @user.errors.full_messages,:email => @user.email}
  #       end
  #   elsif !@user.authenticate(user_params[:current_password])
  #       render :edit => {:status => 'fail',  :errors => @user.errors.full_messages,:email => @user.email}
  #   end
  #
  # end

  def updatePassword
    # if resource.email != params[:email] || params[:password].present?
    @user.current_step = (user_params[:current_step].present?)? user_params[:current_step] : ""
    gon.current_step = @user.current_step
    if @user && @user.authenticate(user_params[:current_password]) && @user.activated
        if @user.update_attributes(:password => user_params[:new_password])
          flash[:notice] = "Password updated"
          render :json => {:status => 'success', :email => @user.email}
        else
          render :json => {:status => 'fail',  :errors => @user.errors.full_messages}
        end
    elsif !@user.authenticate(user_params[:current_password])
        render :json => {:status => 'fail',  :errors => @user.errors.full_messages}
    end

  end

  def destroy
    # authorize @current_user
    if (!params[:type].blank? && params[:type]=="collaborator")
      @collaboration = Collaboration.find_by(user_id: @user.id, list_id: @list.id)
      @collaboration.destroy
      Collaboration.reset_pk_sequence
      # @created_list = @user.created_lists.build(:name =>@list.name, :description => @list.description, :image => @list.image)
      # if @created_list.save
      #   @created_list.tasks << @list.tasks.where(user_id:@user.id)
      # end

      @invitations = @list.invitations.where(recipient_email: @user.email)
      @invitationId = (Invitation.find_by(recipient_email: @user.email, list_id: @list.id).blank? )? "" : Invitation.find_by(recipient_email: @user.email, list_id: @list.id).id
      @invitations.delete_all
      Invitation.reset_pk_sequence
      invitation_caption_html = ""
      member_caption_html = ""
      if (@list.invitations.count == 0)
        invitation_caption_html = ApplicationController.render(partial:
                      'layouts/li_caption', locals: {message: "This list don't have pending invitation at this time"})
      end
      if (@list.collaboration_users.count == 0)
        member_caption_html = ApplicationController.render(partial:
                      'layouts/li_caption', locals: {message: "This list don't have members at this time"})
      end
      ActionCable.server.broadcast "invitation_channel", status: 'collaboratorDeleted', email: @user.email, recipient: @user.id, list_id: @list.id, id: @invitationId, invitation_caption_html: invitation_caption_html, member_caption_html: member_caption_html
      flash[:notice] = "#{@user.first_name} was successfully destroyed as collaborator."
    else
      @user.destroy
      User.reset_pk_sequence
      flash[:notice] = 'User was successfully destroyed.'
    end
    respond_to do |format|
      format.json { head :no_content }
      format.js
    end
  end


  def resend_activation
    @user = User.find_by(email:params[:email])
    @user.update_activation_digest
    # @user.send_activation_email
    # flash[:info] = "Account not activated. You need to activate your account first."
    # flash[:info] += " Check your email for the activation link."

    # @user.activation_token = User.new_token
    # @user.create_activation_digest
    # @user.send_activation_email
    UserMailer.account_activation(@user).deliver_now
    flash[:info] = "Please check your email to activate your account."
    redirect_to login_url
  end


  def sort
    # authorize @tasks.first
    if  !params[:collaboration_user].blank?
      collaboration_user = params[:collaboration_user]
    elsif !params[:list_user].blank?
      collaboration_user = params[:list_user]
    end

    collaboration_user.map!(&:to_i)
    active_collaborations = session[:active_collaborations]

    collaboration_user.each_with_index do |id, index|
      if active_collaborations.include?(id)
        value = active_collaborations[index]
        pos = active_collaborations.index(id)
        active_collaborations[index] = id
        active_collaborations[pos] = value
      end
      Collaboration.where(:user_id=> id, :list_id => params[:list_id]).update_all(position: index + 1)

    end

    session[:active_collaborations] = active_collaborations
    head :ok
  end

  private

  def needs_password?(user, params)
    user.email != params[:user][:email]
  end

  def user_not_authorized
    flash[:alert] = "You are not cool enough to do this - go back from whence you came."
    redirect_to(root_path)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    if ((params[:user_id].blank?) && (params[:type].blank?))
      @user = current_user
    elsif (!params[:type].blank?) && (params[:type]== 'collaborator')
        @user = User.find(params[:id])
    else
      @user = User.find(params[:user_id])
    end
  end

  def set_list
    @list = List.find(params[:list_id])
    # byebug
    # @list = List.find(params[:list_id])
    # if @list != List.current
    #   @_current_list = session[:list_id] = nil
    #   session[:list_id] = params[:list_id]
    #   @_current_list = List.current = @list
    # end

  end
  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    params.require(:user).permit(
    :first_name,
    :last_name,
    :image,
    :image_original_w,
    :image_original_h,
    :crop_x,
    :crop_y,
    :crop_w,
    :crop_h,
    :email,
    :password,
    :password_confirmation,
    :current_step,
    :new_email,
    :new_email_confirmation,
    :current_password).reject { |_, v| v.blank? }


  end
  # Remembers a user in the database for use in persistent sessions.
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  def validate_update

      @first_name = user_params[:first_name]
      @new_email = user_params[:new_email].to_s.downcase.strip
      @new_email_confirmation = user_params[:new_email_confirmation].to_s.downcase.strip
      @current_password = user_params[:current_password]
      @validate_update = false
      numberoferror = 0

      if @first_name.blank?
        @user.errors.add(:first_name,:blank,message: "cannot be blank")
        numberoferror += 1
      end

      if !@new_email.blank?
      #   @user.errors.add(:new_email,message: "Email cannot be blank")
      #   numberoferror += 1
      # end
          if @new_email_confirmation.blank?
            @user.errors.add(:new_email_confirmation, :blank, message: "confirmation Email cannot be blank")
            numberoferror += 1
          end

          if (!@new_email.blank?) && (!@new_email_confirmation.blank?)
            if @new_email != @new_email_confirmation
              @user.errors.add(:new_email_confirmation, :not_confirmed,message: "confirmation Email must be the same as the Email")
              numberoferror += 1
            end
          end

          if  @new_email == current_user.email
            @user.errors.add(:new_email,:same, message: "current Email and New email cannot be the same")
            numberoferror += 1
          end

          if User.email_used?(@new_email)
            @user.errors.add(:new_email,:in_use, message: "is already in use.")
            numberoferror += 1
          end

          if @current_password.blank?
            @user.errors.add(:password, :blank,message: "cannot be blank.")
            numberoferror += 1
          end

          if @user
            if !@user.authenticate(user_params[:current_password])
              @user.errors.add(:password, :incorrect,message: "is not correct.")
              numberoferror += 1
            end

            # if @user.activated
            #   @user.errors.add(:user, :activated, message: "is not activated.")
            #   numberoferror += 1
            # end
          end
      end

      if numberoferror != 0

        # render :edit => {:status => 'fail',  :errors => @user.errors.full_messages}
        return false

         #redirect_to  settings_user_path(@user) and return
          # return render json: { status: 'invalid',:errors => @user.errors.messages }, status: :bad_request
      else
        return true
      end
      # if numberoferror != 0
        # @validate_update = true if ( numberoferror == 0 )    #render json: { status: 'invalid',:errors => @user.errors.messages }, status: :bad_request
      # end

  end

  # def validate_email_update
  #
  #     @new_email = user_params[:new_email].to_s.downcase
  #     @new_email_confirmation = user_params[:new_email_confirmation].to_s.downcase
  #     @current_password = user_params[:current_password]
  #
  #     numberoferror = 0
  #     if @new_email.blank?
  #       @user.errors.add(:new_email,message: "Email cannot be blank")
  #       numberoferror += 1
  #     end
  #
  #     if @new_email_confirmation.blank?
  #       @user.errors.add(:new_email_confirmation, message: "Confirmation Email cannot be blank")
  #       numberoferror += 1
  #     end
  #
  #     if (!@new_email.blank?) && (!@new_email_confirmation.blank?)
  #       if @new_email != @new_email_confirmation
  #         @user.errors.add(:new_email_confirmation, message: "Confirmation Email must be the same as the Email")
  #         numberoferror += 1
  #       end
  #     end
  #
  #     if  @new_email == current_user.email
  #       flash[:alert] = 'Current Email and New email cannot be the same'
  #       @user.errors.add(:new_email,message: "Current Email and New email cannot be the same")
  #       numberoferror += 1
  #     end
  #
  #     if User.email_used?(@new_email)
  #       @user.errors.add(:new_email, message: "Email is already in use.")
  #       numberoferror += 1
  #     end
  #
  #     if @current_password.blank?
  #       @user.errors.add(:password, message: "Password cannot be blank.")
  #       numberoferror += 1
  #     end
  #
  #     if numberoferror != 0
  #       return render json: { status: 'invalid',:errors => @user.errors.messages }, status: :bad_request
  #     end
  # end


  def validate_password_update

      @new_password_reset_url = user_params[:new_password].to_s.downcase
      @new_password_confirmation = user_params[:new_password_confirmation].to_s.downcase
      @current_password = user_params[:current_password]

      numberoferror = 0
      if @new_password.blank?
        @user.errors.add(:new_password, "cannot be blank")
        numberoferror += 1
      end

      if @new_password_confirmation.blank?
        @user.errors.add(:new_password_confirmation,"cannot be blank")
        numberoferror += 1
      end

      if (!@new_password.blank?) && (!@new_password_confirmation.blank?)
        if @new_password != @new_password_confirmation
          @user.errors.add(:new_password_confirmation, "must be the same as the password")
          numberoferror += 1
        end
      end

      if  @new_password == current_user.password
        # flash[:alert] = 'Current password and New password cannot be the same'
        @user.errors.add(:new_password,"and current password cannot be the same")
        numberoferror += 1
      end

      if @current_password.blank?
        @user.errors.add(:password, "cannot be blank.")
        numberoferror += 1
      end

      if numberoferror != 0
        return render edit: { status: 'invalid',:errors => @user.errors.full_messages }
      end
  end

  def set_active_collaborations
    @active_collaborations = session[:active_collaborations]
    @active_collaborations ||= Array.new
    (@active_collaborations.include?(@user.id))? @active_collaborations.delete(@user.id) : @active_collaborations.push(@user.id)
    session[:active_collaborations] = @active_collaborations
  end

  def set_active_all_collaborations
    @users = current_list.collaboration_users.where.not(id: current_user.id)
    @active_collaborations = session[:active_collaborations]
    @active_collaborations ||= Array.new

    if @users.ids.index{ |x| !@active_collaborations.include?(x) }.nil?
      @active_collaborations = []
    else
      @active_collaborations = @users.ids
      if !current_user.owner?(current_list)
        @active_collaborations.push(current_list.user_id)
      end
    end
    session[:active_collaborations] = @active_collaborations
  end
end
