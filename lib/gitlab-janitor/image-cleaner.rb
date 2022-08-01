require 'awesome_print'

module GitlabJanitor
  class ImageCleaner < BaseCleaner

    class Model < BaseCleaner::Model

      def initialize(v, name, store)
        super(v)
        @store = store
        @name = name

        info['_Age'] = (Time.now - Time.at(loaded_at)).round(0)
      end

      def loaded_at
        @store.image(self)[:loaded_at]
      end

      def name
        @name || id
      end

      def age
        info['_Age']
      end

      def id
        info['id']
      end

    end

    class Store

      attr_reader :logger, :filename, :images

      def initialize(logger:, filename: './images.txt')
        @filename = filename
        @logger = logger
      end

      def parse_images
        Docker::Image.all.map do |m|
          tags = m.info.fetch('RepoTags', [])
          tags = [m.info['id']] if tags.empty? || tags.first == '<none>:<none>'
          m.info['RepoTags'] = tags

          tags.map do |name|
            Model.new(m, name, self)
          end
        end.flatten
      end

      def load
        containers = Docker::Container.all(all: true).each_with_object({}) do |c, res|
          res[c.info['ImageID']] = true
          res[c.info['Image']] = true
        end

        File.open(@filename, 'a+') do |file|
          i = 0
          @images = file.readlines.select(&:present?).each_with_object({}) do |line, imgs|
            i += 1
            name, image_id, loaded_at = line.strip.split(' ')
            loaded_at = Time.now.to_i if containers[name] || containers[image_id]

            imgs[name] = { id: image_id, loaded_at: Time.at(loaded_at.to_i) }
          rescue StandardError => e
            logger.error "Unable to load from line #{i} '#{line}': #{e}"
          end
        end
        @images
      end

      def image(img)
        @images[img.name] ||= { id: img.id, loaded_at: Time.now }
      end

      def save(imgs = parse_images, skip_older: Time.at(0))
        @images = @images.delete_if do |_k, img|
          img[:loaded_at] < skip_older
        end

        imgs.each {|m| image(m) }

        File.open(@filename, 'w+') do |file|
          @images.each do |name, data|
            file.puts("#{name} #{data[:id]} #{data[:loaded_at].to_i}")
          end
        end
      end

    end

    def initialize(**kwargs)
      super
      @store = Store.new(logger: logger)
    end

    def do_clean(remove: false)
      @store.load
      to_remove, keep = prepare(@store.parse_images)
      @store.save(skip_older: Time.now - @deadline)

      unless to_remove.empty?
        keep.each do |m|
          logger.debug("  KEEP #{format_item(m)}")
        end

        if remove
          logger.info 'Removing images...'
          to_remove.each do |c|
            logger.tagged(c.name) do
              logger.debug '   Removing...'
              log_exception('Remove') { `docker rmi #{c.name}` }
              logger.debug '   Removing COMPLETED'
            end
          end
        else
          logger.info 'Skip removal due to dry run'
        end
      end
    end

    def prepare(images)
      to_remove = images
      @logger.info("Selected images: \n#{to_remove.map{|c| "  + #{format_item(c)}" }.join("\n")}")

      @logger.debug("Filtering images by deadline: older than #{Fugit::Duration.parse(@deadline).deflate.to_plain_s}...")
      to_remove = select_by_deadline(to_remove)
      if to_remove.empty?
        @logger.info('Noting to remove.')
        return [], images
      end
      @logger.info("Filtered images: \n#{to_remove.map{|c| "  !! #{format_item(c)}" }.join("\n")}")

      [to_remove, (images - to_remove)]
    end

    def format_item(m)
      "#{m.loaded_at} Age:#{Fugit::Duration.parse(m.age).deflate.to_plain_s.ljust(13)} #{m.name.first(60).ljust(60)}"
    end

    def select_by_deadline(containers)
      containers.select do |c|
        c.age > deadline
      end
    end

  end
end

