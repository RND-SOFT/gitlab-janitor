module GitlabJanitor
  class ContainerCleaner < BaseCleaner

    class Model < BaseCleaner::Model

      def initialize(model)
        super(model)

        info['_Age'] = (Time.now - Time.at(created_at)).round(0)
      end

      def created_at
        info['Created']
      end

      def name
        @name ||= info['Names'].first.sub(%r{^/}, '')
      end

      def age
        info['_Age']
      end

      def age_text
        Fugit::Duration.parse(age).deflate.to_plain_s
      end

    end

    attr_reader :excludes, :includes

    def initialize(includes: [''], excludes: [''], **args)
      super(**args)
      @includes = includes
      @excludes = excludes
      @deadline = deadline
    end

    def do_clean(remove: false)
      to_remove, keep = prepare(Docker::Container.all(all: true).map{|m| Model.new(m) })

      return if to_remove.empty?

      keep.each {|m| logger.debug("  KEEP #{m.name}") }

      if remove
        logger.info 'Removing containers...'
        to_remove.each do |c|
          logger.tagged(c.name) do
            logger.debug '   Removing...'
            log_exception('Stop') { c.stop }
            log_exception('Wait') { c.wait(15) }
            log_exception('Remove') { c.remove }
            logger.debug '   Removing COMPLETED'
          end
        end
      else
        logger.info 'Skip removal due to dry run'
      end
    end

    def prepare(containers)
      @logger.debug("Selecting containers by includes #{@includes}...")
      to_remove = select_by_name(containers)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], containers
      end
      @logger.info("Selected containers: \n#{to_remove.map{|c| "  + #{format_item(c)}" }.join("\n")}")

      @logger.debug("Filtering containers by excludes #{@excludes}...")
      to_remove = reject_by_name(to_remove)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], containers
      end
      @logger.info("Filtered containers: \n#{to_remove.map{|c| "  + #{format_item(c)}" }.join("\n")}")

      @logger.debug("Filtering containers by deadline: older than #{Fugit::Duration.parse(@deadline).deflate.to_plain_s}...")
      to_remove = select_by_deadline(to_remove)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], containers
      end
      @logger.info("Filtered containers: \n#{to_remove.map{|c| "  + #{format_item(c)}" }.join("\n")}")

      [to_remove, containers - to_remove]
    end

    def format_item(model)
      "#{Time.at(model.created_at)} Age:#{model.age_text.ljust(10)} #{model.name.first(60).ljust(60)}"
    end

    def select_by_name(containers)
      containers.select do |model|
        @includes.any? do |pattern|
          File.fnmatch(pattern, model.name)
        end
      end
    end

    def reject_by_name(containers)
      containers.reject do |model|
        @excludes.any? do |pattern|
          File.fnmatch(pattern, model.name)
        end
      end
    end

    def select_by_deadline(containers)
      containers.select do |model|
        model.age > deadline
      end
    end

  end
end

