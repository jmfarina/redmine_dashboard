# frozen_string_literal: true

class RdbTaskboardController < RdbDashboardController
  menu_item :dashboard

  def board_type
    RdbTaskboard
  end

  def move
    return flash_error(:rdb_flash_invalid_request) unless (column = @board.columns[params[:column].to_s])

    # Get all status the user is allowed to assign and that are in the target column
    @statuses = @issue.new_statuses_allowed_to(User.current) & column.statuses

    if @statuses.empty?
      return flash_error :rdb_flash_illegal_workflow_action,
                         issue: @issue.subject, source: @issue.status.name, target: column.title
    end

    # Show dialog if more than one status are available
    return render 'rdb_dashboard/taskboard/column_dialog' if @statuses.many?

    params[:status] = @statuses.first.id
    update
  end

  def update
    @issue.init_journal(User.current, params[:notes] || nil)

    @issue.done_ratio = params[:done_ratio].to_i if params[:done_ratio]

    if params[:unassigne_me] && @issue.assigned_to_id == User.current.id
      @issue.assigned_to_id = nil
    elsif params[:assigne] && !params[:assigne].empty?
      # if we receive an int, try to recover a user by id
      if !Integer(params[:assigne].to_s, exception: false).nil?
        begin
          new_user = (User.find params[:assigne].to_i)
        rescue ActiveRecord::RecordNotFound
          puts "User not found! #{params[:assigne].to_i}"
          return flash_error :rdb_flash_invalid_request
        end
      elsif params[:assigne] == "none"
        new_user = nil
      elsif params[:assigne] == "me"
        new_user = User.current
      else
        return flash_error :rdb_flash_invalid_request
      end

      @issue.assigned_to_id = new_user.nil? ? nil : new_user.id # TODO validate that user can change assignation
    elsif params[:assigne_me] || @board.options[:change_assignee]
      @issue.assigned_to_id = User.current.id
    end

    if params[:status]
      status = IssueStatus.find params[:status].to_i
      if @issue.new_statuses_allowed_to(User.current).include?(status)
        @issue.status = status
      else
        return flash_error :rdb_flash_illegal_workflow_action,
                           issue: @issue.subject, source: @issue.status.name, target: @status.name
      end
    end

    if params[:version]
      begin
        version = params[:version].empty? ? nil : (Version.find params[:version].to_i)
      rescue ActiveRecord::RecordNotFound
        return flash_error :rdb_flash_invalid_request
      end

      if @issue.assignable_versions.include?(version) || version.nil? # TODO validate that user can change version?
        @issue.fixed_version = version
      end
    end

    Issue.transaction do
      call_hook(
        :controller_issues_edit_before_save,
        {
          params: {},
          issue: @issue,
          journal: @issue.current_journal
        },
      )

      if @issue.save
        call_hook(
          :controller_issues_edit_after_save,
          {
            params: {},
            issue: @issue,
            journal: @issue.current_journal
          },
        )
      else
        raise ActiveRecord::Rollback
      end
    end

    render 'index'
  end
end
