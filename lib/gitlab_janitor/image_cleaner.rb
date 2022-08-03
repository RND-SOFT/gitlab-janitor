require 'open3'

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

    def initialize(image_store:, **kwargs)
      super(**kwargs)
      @store = Store.new(filename: image_store, logger: logger)
    end

    def do_clean(remove: false)
      store.load
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

  end
end

