module GitlabJanitor
  class VolumeCleaner < BaseCleaner

    class Model < BaseCleaner::Model

      def initialize(model)
        super(model)

        info['_Age'] = (Time.now - Time.parse(created_at)).round(0)
      end

      def created_at
        info['CreatedAt']
      end

      def name
        info['Name']
      end

      def age
        info['_Age']
      end

      def age_text
        Fugit::Duration.parse(age).deflate.to_plain_s
      end

      def mountpoint
        info['Mountpoint']
      end

    end

    attr_reader :includes

    def initialize(includes: [''], **kwargs)
      super(**kwargs)
      @includes = includes
    end

    def do_clean(remove: false)
      to_remove, keep = prepare(Docker::Volume.all.map{|m| Model.new(m) })

      return if to_remove.empty?

      keep.each {|m| logger.debug("  KEEP #{m.name}") }

      if remove
        logger.info 'Removing volumes...'
        to_remove.each do |model|
          return false if exiting?

          logger.tagged(model.name.first(10)) do
            logger.debug '   Removing...'
            log_exception('Remove') { model.remove }
            logger.debug '   Removing COMPLETED'
          end
        end
      else
        logger.info 'Skip removal due to dry run'
      end
    end

    def prepare(volumes)
      @logger.debug('Selecting unnamed volumes...')
      to_remove = select_unnamed(volumes)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], volumes
      end
      @logger.info("Selected volumes: \n#{to_remove.map{|c| "  + #{format_item(c)}" }.join("\n")}")

      @logger.debug("Selecting volumes by includes #{@includes}...")
      to_remove += select_by_name(volumes)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], images
      end
      @logger.info("Selected volumes: \n#{to_remove.map{|c| "  + #{format_item(c)}" }.join("\n")}")

      @logger.debug("Filtering volumes by deadline: older than #{@deadline} seconds...")
      to_remove = select_by_deadline(to_remove)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], volumes
      end
      @logger.info("Filtered volumes: \n#{to_remove.map{|c| "  !! #{format_item(c)}" }.join("\n")}")

      [to_remove, (volumes - to_remove)]
    end

    def format_item(model)
      "#{Time.parse(model.created_at)} Age:#{model.age_text.ljust(13)} #{model.name.first(10).ljust(10)} #{model.mountpoint}"
    end

    def select_by_name(volumes)
      volumes.select do |model|
        @includes.any? do |pattern|
          File.fnmatch(pattern, model.name)
        end
      end
    end

    SHA_RX = /^[a-zA-Z0-9]{64}$/.freeze

    def select_unnamed(volumes)
      volumes.select do |model|
        SHA_RX.match(model.name)
      end
    end

    def select_by_deadline(volumes)
      volumes.select do |model|
        model.age > deadline
      end
    end

  end
end

