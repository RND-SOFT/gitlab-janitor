module GitlabJanitor
  class ImageCleaner
    class Store

      attr_reader :logger, :filename, :images

      def initialize(logger:, filename: './images.txt')
        @filename = filename
        @logger = logger
      end

      def parse_images
        Docker::Image.all.map do |m|
          tags = m.info.fetch('RepoTags', []) || []
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
  end
end

