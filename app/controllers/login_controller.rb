class LoginController < ApplicationController
  include LoginHelper

  def new
    gon.current_user = current_user
    @token = params[:invitation_token]
  end

  def create
      user = User.find_by_email(params[:session][:email].downcase)
      # If the user exists AND the password entered is correct.
      if user && user.authenticate(params[:session][:password]) && user.activated
        # Save the user id inside the browser cookie. This is how we keep the user
        # logged in when they navigate around our website.
        @token = params[:invitation_token]
        @invitation = Invitation.find_by_token(@token)
        if (!@token.nil?)&&(user.email==@invitation.recipient_email)
          @list = List.find(@invitation.list_id)
          @invitation.update_attributes(:active => true)
          @collaboration = Collaboration.find_by(list_id: @list.id,user_id: user.id)
          @collaboration.update_attributes(:collaboration_date => Time.now)
          hasCollaborationsList = user.collaboration_lists.count > 0 ? true : false
          unless user.collaboration_lists.include?(@list)
             user.collaboration_lists.push(@list)  #add this user to the list as a collaborator
          end
          htmlCollaborationUser = ListsController.render(partial: "lists/collaboration_user", locals: {"collaboration_user": user, "current_list": @list,"active_users": [], "current_user": current_user}).squish
          htmlListMembersSettings = ListsController.render(partial: "lists/edit/list_members", locals: {"list": @list, "member": user }).squish
          htmlCollaborationsList = ListsController.render(partial: "lists/nav_list_name", layout: "li_navigation", locals: {list: @list, user: user, active: false}).squish
          htmlUserAcceptedInvitation = UsersController.render(partial: "users/accepted_invitation", locals: {accepted_invitation: @invitation}).squish
          ActionCable.server.broadcast 'invitation_channel', status: 'activated',id: @invitation.id, htmlCollaborationUser: htmlCollaborationUser, htmlListMembersSettings: htmlListMembersSettings, owner: @list.owner.id, sender:@invitation.sender_id, recipient: @invitation.recipient.id, list_id: @list.id, htmlCollaborationsList: htmlCollaborationsList, hasCollaborationsList: hasCollaborationsList, htmlUserAcceptedInvitation: htmlUserAcceptedInvitation
        end
        log_in user
        params[:session][:remember_me] == '1' ? remember(user) : forget(user)
        redirect_to root_url
      elsif user && !user.activated
        user.update_activation_digest
        user.send_activation_email
        flash[:danger] = "Account not activated. You need to activate your account first."
        flash[:danger] += " Check your email for the activation link."
        render 'new'
      else
        # If user's login doesn't work, send them back to the login form.
        flash.now[:danger] = 'Invalid email or password combination'
        render 'new'
      end
    end

    def destroy

      log_out if logged_in?

      flash[:success] = 'Logged out successfully.'
      redirect_to confirmation_page_url
    end

end
