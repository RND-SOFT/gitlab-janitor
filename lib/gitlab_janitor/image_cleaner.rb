require 'open3'
require 'redis'

module GitlabJanitor
  class ImageCleaner < BaseCleaner

    class Model < BaseCleaner::Model

      attr_reader :store

      def initialize(model, name, store)
        super(model)
        @store = store
        @name = name

        info['_Age'] = (Time.now - Time.at(loaded_at)).round(0)
      end

      def loaded_at
        store.image(self)[:loaded_at]
      end

      def name
        @name || id
      end

      def age
        info['_Age']
      end

      def age_text
        Fugit::Duration.parse(age).deflate.to_plain_s
      end

      def id
        info['id']
      end

    end

    require_relative 'image_cleaner/store'

    attr_reader :store

    def initialize(image_store:, redis: nil, redis_list: 'gitlab-janitor:images_force_clean', **kwargs)
      super(**kwargs)
      @store = Store.new(filename: image_store, logger: logger)
      @redis_url = redis
      @redis_list = redis_list
    end

    def do_clean(remove: false)
      store.load

      force_clean(remove: remove)

      to_remove, keep = prepare(store.parse_images)
      store.save(skip_older: Time.now - @deadline)

      return if to_remove.empty?

      keep.each {|m| logger.debug("  KEEP #{m.name}") }

      if remove
        logger.info 'Removing images...'
        to_remove.each do |model|
          return false if exiting?

          logger.tagged(model.name) do
            logger.debug '   Removing...'
            log_exception('Remove') { out, _status = Open3.capture2e("docker rmi #{model.name}"); logger.info(out) }
            logger.debug '   Removing COMPLETED'
          end
        end
      else
        logger.info 'Skip removal due to dry run'
      end
    ensure
      if remove
        logger.info 'docker image prune -f'
        out, _status = Open3.capture2e("docker image prune -f")
        logger.info(out)
      end
    end

    def prepare(images)
      to_remove = images

      @logger.info("Selected images: \n#{to_remove.map{|c| "  + #{format_item(c)}" }.join("\n")}")

      @logger.info("Filtering images by deadline: older than #{Fugit::Duration.parse(@deadline).deflate.to_plain_s}...")
      to_remove = select_by_deadline(to_remove)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], images
      end
      @logger.info("Filtered images: \n#{to_remove.map{|c| "  !! #{format_item(c)}" }.join("\n")}")

      [to_remove, (images - to_remove)]
    end

    def format_item(model)
      "#{model.loaded_at} Age:#{model.age_text.ljust(13)} #{model.name.first(60).ljust(60)}"
    end

    def select_by_deadline(images)
      images.select do |model|
        model.age > deadline
      end
    end

    def force_clean(remove: false)
      return if @redis_url.nil?
      logger.info("Force clean image from #{@redis_url}/#{@redis_url}...")

      redis = Redis.new(url: @redis_url)
      redis.ltrim(@redis_list, 0, 100)
      now = Time.now
      redis.lrange(@redis_list, 0, -1).each do |pair|
        image, ts = pair.split('|')
        if (now - Time.at(ts.to_i)) > 10.seconds
          if remove
            logger.info("Force clean #{image}")
            log_exception('Remove') { out, _status = Open3.capture2e("docker rmi #{image}"); logger.info(out) }
          else
            logger.info("Skip Force clean #{image} due to dry run")
          end
        else
          logger.info("Delay force clean #{image} by time")
        end
      rescue StandardError => e
        logger.error("Error from force line: '#{pair}': #{e.inspect}")
      end
    rescue StandardError => e
      logger.error("Unable to retrieve data from redis: #{e}")
    end

  end
end

