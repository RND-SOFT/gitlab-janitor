module GitlabJanitor
  class ContainerCleaner < BaseCleaner

    class Model < BaseCleaner::Model
      def initialize(v)
        super(v)

        info['_Age'] = (Time.now - Time.at(created_at)).round(0)
      end

      def created_at
        info['Created']
      end

      def name
        @anme ||= info['Names'].first.sub(/^\//, '')
      end

      def age
        info['_Age']
      end
    end

    attr_reader :excludes, :includes

    def initialize includes: [''], excludes: [''], **args
      super(**args)
      @includes = includes
      @excludes = excludes
      @deadline = deadline
    end

    def do_clean(remove: false)
      to_remove, keep = prepare(Docker::Container.all(all: true).map{|m| Model.new(m)})

      if !to_remove.empty?
        keep.each do |c|
          logger.debug("  KEEP #{c.name}")
        end

        if remove
          logger.info "Removing containers..."
          to_remove.each do |c|
            logger.tagged(c.name) do
              logger.debug "   Removing..."
              log_exception("Stop") {c.stop}
              log_exception("Wait") {c.wait(15)}
              log_exception("Remove") {c.remove}
              logger.debug "   Removing COMPLETED"
            end
          end
        else
          logger.info "Skip removal due to dry run"
        end
      end
    end


    def prepare containers
      @logger.debug("Selecting containers by includes #{@includes}...")
      to_remove = select_by_name(containers)
      if to_remove.empty?
        @logger.info("Noting to remove.")
        return [], containers
      end
      @logger.info("Selected containers: \n#{to_remove.map{|c| "  + #{format_item(c)}"}.join("\n")}")

      @logger.debug("Filtering containers by excludes #{@excludes}...")
      to_remove = reject_by_name(to_remove)
      if to_remove.empty?
        @logger.info("Noting to remove.")
        return [], containers
      end
      @logger.info("Filtered containers: \n#{to_remove.map{|c| "  + #{format_item(c)}"}.join("\n")}")

      @logger.debug("Filtering containers by deadline: older than #{Fugit::Duration.parse(@deadline).deflate.to_plain_s}...")
      to_remove = select_by_deadline(to_remove)
      if to_remove.empty?
        @logger.info("Noting to remove.")
        return [], containers
      end
      @logger.info("Filtered containers: \n#{to_remove.map{|c| "  + #{format_item(c)}"}.join("\n")}")

      [to_remove, containers - to_remove]
    end

    def format_item c
      "#{Time.at(c.created_at)} Age:#{Fugit::Duration.parse(c.age).deflate.to_plain_s.ljust(10)} #{c.name.first(60).ljust(60)}"
    end

    def select_by_name containers
      containers.select do |c|
        @includes.any? do |pattern|
          File.fnmatch(pattern, c.name)
        end
      end
    end

    def reject_by_name containers
      containers.reject do |c|
        @excludes.any? do |pattern|
          File.fnmatch(pattern, c.name)
        end
      end
    end

    def select_by_deadline containers
      containers.select do |c|
        c.age > deadline
      end
    end

  end
end