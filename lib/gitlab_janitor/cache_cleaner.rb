require 'open3'

module GitlabJanitor
  class CacheCleaner < BaseCleaner

    def initialize(**kwargs)
      super(**kwargs)
    end

    def do_clean(keep_size: '10G', remove: false)
      logger.info 'Removing cache...'
      if remove
        out, _status = Open3.capture2e("docker builder prune --keep-storage #{keep_size} -f")
        logger.info(out)
      else
        logger.info 'Skip removal due to dry run'
      end
      out, _status = Open3.capture2e('docker system df')
      logger.info(out)
    end

  end
end

