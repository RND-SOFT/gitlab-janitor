require 'open3'

module GitlabJanitor
  class CacheCleaner < BaseCleaner

    def initialize(**kwargs)
      super(**kwargs)
    end

    def do_clean(keep_size: '10G', remove: false)
      logger.info 'Removing cache...'
      if remove
        prune_builder(keep_size)
        prune_buildx(keep_size)
      else
        logger.info 'Skip removal due to dry run'
      end
      out, _status = Open3.capture2e('docker system df')
      logger.info(out)
    end
    
    def prune_builder(keep_size)
      out, _status = Open3.capture2e("docker builder prune --keep-storage #{keep_size} -f")
      logger.info(out)
    rescue StandardError =>e
      logger.warn("Unable to clean BUILDER: #{e.inspect}")
    end
    
    def prune_buildx(keep_size)
      out, _status = Open3.capture2e("docker buildx prune --keep-storage #{keep_size} -f")
      logger.info(out)
    rescue StandardError =>e
      logger.warn("Unable to clean BUILDX: #{e.inspect}")
    end

  end
end

