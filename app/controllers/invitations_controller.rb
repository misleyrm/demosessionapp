class InvitationsController < ApplicationController
  layout "modal"
  include InvitationsHelper
  before_action :require_logged_in
  before_action :set_list
  before_action :set_invitation, only: [:show, :destroy, :resend_invitation, :update]

  def index
    @invitations = Invitation.all.sort_by(&:created_at)
  end

  def show
    render layout: 'modal'
  end

  def new
    @invitation = Invitation.new
    render layout: 'modal'
    # render layout: 'modal'
  end

  def create
    @invitation = Invitation.new(invitation_params)
    @invitation.sender_id = current_user.id
    respond_to do |format|
      if @invitation.save
          if @invitation.recipient != nil
              @url = login_url(:invitation_token => @invitation.token)
              @recipient = @invitation.recipient
              #send a notification email
              InvitationMailer.existing_user_invite(@invitation, @url).deliver_later
              unless @invitation.recipient.collaboration_lists.include?(@list)
                 @recipient.collaboration_lists.push(@list)  #add this user to the list as a collaborator
                 htmlListMembersSettings = ListsController.render(partial: "lists/edit/list_members", locals: {list: @list,member: @recipient,current_user: current_user  }).squish
                 htmlInvitationSetting = ListsController.render(partial: "lists/edit/list_pending_invitation", locals: {list: @list,"pending_invitation": @invitation }).squish
                 htmlCollaborationUser = ListsController.render(partial: "lists/collaboration_user", locals: {"collaboration_user": @recipient, "current_list": @list, "active_users": [],current_user: current_user}).squish
                 htmlUserPendingInvitation = UsersController.render(partial: "users/pending_invitation", locals: {pending_invitation: @invitation}).squish
                 ActionCable.server.broadcast 'invitation_channel', status: 'created',id: @invitation.id, htmlCollaborationUser: htmlCollaborationUser, htmlListMembersSettings: htmlListMembersSettings, htmlInvitationSetting: htmlInvitationSetting, sender:@invitation.sender_id, recipient: @recipient.id, list_id: @list.id, owner: @list.owner.id, existing_user_invite: true, htmlUserPendingInvitation: htmlUserPendingInvitation
              end
            else
              @url = sign_up_url(:invitation_token => @invitation.token)
              InvitationMailer.send_invitation(@invitation, @url).deliver_later #send the invite data to our mailer to deliver the email
              htmlInvitationSetting = ListsController.render(partial: "lists/edit/list_pending_invitation", locals: { "pending_invitation": @invitation, "list": @list }).squish
              ActionCable.server.broadcast 'invitation_channel', status: 'created',id: @invitation.id, htmlInvitationSetting: htmlInvitationSetting, sender:@invitation.sender_id, recipient: @invitation.recipient_id, list_id: @list.id,owner: @list.owner.id, existing_user_invite: false
            end

        flash[:notice] = "Invitation sent successfully."
      end
      @htmlerrors = InvitationsController.render(partial: "shared/error_messages", locals: {"object": @invitation}).squish
      format.json { render :json => {:htmlerrors => @htmlerrors  }}
      format.js { }
    end
  end

  def update
    @user = current_user
    @token = params[:invitation_token]

    if (!@token.nil?) && (@user == @invitation.recipient)
        # @list = List.find(@invitation.list_id)
        @invitation.update_attributes(:active => true)
        @collaboration = Collaboration.find_by(list_id: @list.id,user_id: @user.id)
        @collaboration.update_attributes(:collaboration_date => Time.now)
        hasCollaborationsList = @user.collaboration_lists.count > 0 ? true : false
        unless @user.collaboration_lists.include?(@list)
           @user.collaboration_lists.push(@list)  #add this user to the list as a collaborator
        end
        htmlCollaborationUser = ListsController.render(partial: "lists/collaboration_user", locals: {"collaboration_user": @user, "current_list": @list,"active_users": [], "current_user": @user}).squish
        htmlListMembersSettings = ListsController.render(partial: "lists/edit/list_members", locals: {"list": @list, "member": @user }).squish
        htmlCollaborationsList = ListsController.render(partial: "lists/nav_list_name", layout: "li_navigation", locals: {list: @list, user: @user, active: false}).squish
        htmlUserAcceptedInvitation = UsersController.render(partial: "users/accepted_invitation", locals: {accepted_invitation: @invitation}).squish
        ActionCable.server.broadcast "invitation_channel", status: 'activated',id: @invitation.id, htmlCollaborationUser: htmlCollaborationUser, htmlListMembersSettings: htmlListMembersSettings, owner: @list.owner.id, sender:@invitation.sender_id, recipient: @invitation.recipient.id, list_id: @list.id, htmlCollaborationsList: htmlCollaborationsList, hasCollaborationsList: hasCollaborationsList, htmlUserAcceptedInvitation: htmlUserAcceptedInvitation
        respond_to do |format|
          @htmlerrors = InvitationsController.render(partial: "shared/error_messages", locals: {"object": @invitation}).squish
          flash[:notice] = "The invitation accepted."
          format.json { render :json => {:htmlerrors => @htmlerrors }}
          format.js { }
         end

    end

  end


  def resend_invitation
    # @invitation = Invitation.find(id)
    if (@invitation.recipient != nil) || (User.find_by_email(@invitation.recipient_email))
      @url = login_url(:invitation_token => @invitation.token)
      # @recipient = @invitation.recipient
      #send a notification email
      InvitationMailer.existing_user_invite(@invitation, @url).deliver_later
      flash[:notice] = "The invitation was re-sent."
    else
      @url = sign_up_url(:invitation_token => @invitation.token)
      InvitationMailer.send_invitation(@invitation, @url).deliver_later #send the invite
      flash[:notice] = "The invitation was re-sent."
     end
     respond_to do |format|
       format.json { render :json => {:htmlerrors => @htmlerrors }}
       format.js { }
      end
  end

  # DELETE /invitations/1
  # DELETE /invitations/1.json
  def destroy

    @invitation.destroy
    if (@invitation.recipient != nil) && (!@invitation.active)
      @collaboration = Collaboration.find_by(user_id: @invitation.recipient.id, list_id: @invitation.list_id)
      @collaboration.destroy if @collaboration.blank?
    end
    ActionCable.server.broadcast 'invitation_channel', status: 'deleted', id: @invitation.id, list_id: @invitation.list_id,recipient: @invitation.recipient_id, owner: @list.owner.id
    flash[:notice] = 'Invitation was successfully destroyed.'
    respond_to do |format|
      format.json { head :no_content }
      format.js
     end
  end

  private
    def set_invitation
      @invitation = Invitation.find(params[:id])
    end

    def set_list
      @list= List.find(params[:list_id])
    end

    def invitation_params
      params.require(:invitation).permit(:id,:sender_id, :list_id, :recipient_email, :token, :sent_at)
    end
end
