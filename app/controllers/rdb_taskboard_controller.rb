class RdbTaskboardController < RdbDashboardController
  menu_item :dashboard

  def board_type; RdbTaskboard end

  def move
    return flash_error(:rdb_flash_invalid_request) unless column = @board.columns[params[:column].to_s]

    # Ignore workflow if user is admin
    if User.current.admin?
      @statuses = column.statuses
    else
      # Get all status the user is allowed to assign and that are in the target column
      @statuses = @issue.new_statuses_allowed_to(User.current) & column.statuses
    end

    if @statuses.empty?
      return flash_error :rdb_flash_illegal_workflow_action,
        :issue => @issue.subject, :source => @issue.status.name, :target => column.title
    end

    # Show dialog if more than one status are available
    return render 'rdb_dashboard/taskboard/column_dialog' if @statuses.count > 1

    params[:status] = @statuses.first.id
    update
  end

  def update
    #  validate that the user is allowed to edit the issue
    unless @issue.editable?
      return (flash_error :rdb_flash_illegal_workflow_action,
              :issue => @issue.subject, :source => @issue.status.name, :target => column.title)
    end
    
    @issue.init_journal(User.current, params[:notes] || nil)

    @issue.done_ratio = params[:done_ratio].to_i if params[:done_ratio]

    if params[:assigne]
      # Assign to the appropriate target, either numeric (target assigne) or named target
      case params[:assigne].to_s
      when "none"
        @issue.assigned_to_id = nil
      when "me"
        @issue.assigned_to_id = User.current.id
      when "same"
        # FIXME: Refactor proper default         
      else 
        @issue.assigned_to_id = params[:assigne].to_i
      end
    else
      @issue.assigned_to_id = nil if params[:unassigne_me] && @issue.assigned_to_id == User.current.id
      @issue.assigned_to_id = User.current.id if params[:assigne_me]
    end

    if params[:status]
      status = IssueStatus.find params[:status].to_i
      if @issue.new_statuses_allowed_to(User.current).include?(status) or User.current.admin?
        @issue.status         = status
        @issue.assigned_to_id = User.current.id if @board.options[:change_assignee]
      else
        return flash_error :rdb_flash_illegal_workflow_action,
          :issue => @issue.subject, :source => @issue.status.name, :target => @status.name
      end
    end
    
    if params[:version]
      
      # validate that version was found
#      begin
        version = Version.find params[:version].to_i
#        rescue ActiveRecord::RecordNotFound
#          show_error "#{l(:error_version_not_found)} #{params[:version]}" -> refer to recurring_tasks_controller.rb show_error
#      end
      
      if @issue.assignable_versions.include?(version)
        @issue.fixed_version = version
      end
    end

    @issue.save

    render 'index'
  end
end
