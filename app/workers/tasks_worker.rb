class TasksWorker
  include Sidekiq::Worker

  def perform(task_id,data,list_id)

    if (data["status"]!= 'deleted')
      task = Task.find(task_id)
      current_list = List.find(data["current_list"])
      list = List.find(data["list_id"])
      current_user = User.find(data["current_user_id"])
      html = (!current_list.blank?)? render_task(task,current_list,data["partial"],list,current_user) : ""

      ActionCable.server.broadcast "task_list_#{list_id}", {
        data: data,
        html: html
      }
    else
      ActionCable.server.broadcast "task_list_#{list_id}", { data: data }
    end
  end

  def render_task(task,current_list, partial, list, current_user)
    # user = (partial == 't_blocker')? task.parent_task.user : task.user
    TasksController.render(partial: "tasks/#{partial}", locals: {"#{partial}": task, "currentUser": current_user, "list": list, "current_list": current_list }).squish
  end
end
