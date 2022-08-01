module GitlabJanitor
  class VolumeCleaner < BaseCleaner

    class Model < BaseCleaner::Model

      def initialize(v)
        super(v)

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

      def mountpoint
        info['Mountpoint']
      end

    end

    def do_clean(remove: false)
      to_remove, keep = prepare(Docker::Volume.all.map{|m| Model.new(m) })

      unless to_remove.empty?
        keep.each do |c|
          logger.debug("  KEEP #{c.name}")
        end
        if remove
          logger.info 'Removing volumes...'
          to_remove.each do |c|
            logger.tagged(c.name.first(10)) do
              logger.debug '   Removing...'
              log_exception('Remove') { c.remove }
              logger.debug '   Removing COMPLETED'
            end
          end
        else
          logger.info 'Skip removal due to dry run'
        end
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

      @logger.debug("Filtering volumes by deadline: older than #{@deadline} seconds...")
      to_remove = select_by_deadline(to_remove)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], volumes
      end
      @logger.info("Filtered volumes: \n#{to_remove.map{|c| "  !! #{format_item(c)}" }.join("\n")}")

      [to_remove, (volumes - to_remove)]
    end

    def format_item(c)
      "#{Time.parse(c.created_at)} Age:#{Fugit::Duration.parse(c.age).deflate.to_plain_s.ljust(13)} #{c.name.first(10).ljust(10)} #{c.mountpoint}"
    end

    SHA_RX = /^[a-zA-Z0-9]{64}$/

    def select_unnamed(volumes)
      volumes.select do |c|
        SHA_RX.match(c.name)
      end
    end

    def select_by_deadline(containers)
      containers.select do |c|
        c.age > deadline
      end
    end

  end
end

