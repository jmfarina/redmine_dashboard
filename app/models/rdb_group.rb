class RdbGroup
  attr_accessor :board
  attr_reader :name, :options, :id

  # @param id group's id
  # @param name the group's name
  # @param groupType the type of the object associated to this group
  # @param objectId the id of the object associated to this group
  # @param a hash with other options
  def initialize(id, name, groupType = nil, objectId = nil, options = {})
    @id    = id.to_s
    @name  = name
    @groupType = groupType
    @objectId = objectId

    @options = default_options
    @options[:accept] = options[:accept] if options[:accept].respond_to? :call
    @options[:spent_hours] = options[:spent_hours].blank? ? "-" : options[:spent_hours].to_s
    @options[:estimated_hours] = options[:estimated_hours].blank? ? "-" : options[:estimated_hours].to_s
  end

  def default_options
    {}
  end

  def accept?(issue)
    return true if options[:accept].nil?
    options[:accept].call(issue)
  end

  def title
    name.is_a?(Symbol) ? I18n.translate(name) : name.to_s
  end

  def accepted_issues(source = nil)
    @accepted_issues ||= filter((source ? source : board).issues)
  end

  def accepted_issue_ids
    @accepted_issue_ids ||= accepted_issues.map(&:id)
  end

  def filter(issues)
    issues.select{|i| accept? i}
  end

  def visible?
    @visible ||= catch(:visible) do
      board.columns.values.each do |column|
        next if not column.visible? or column.compact?
        throw :visible, true if !board.options[:hide_empty_groups] || filter(column.issues).count > 0
      end
      false
    end
  end

  def issue_count
    filter(@board.issues).count.to_i
  end

  def estimated_hours
    estimated_hours = "-"
    case @groupType
    when "Version"
      estimated_hours = @board.versions.find(@objectId).estimated_hours.to_s unless @objectId.blank?
    end
    return estimated_hours
  end
  
  def spent_hours
    spent_hours = "-"
    case @groupType
    when "Version"
      estimated_hours = @board.versions.find(@objectId).spent_hours.to_s unless @objectId.blank?
    end
    return spent_hours
  end
end
