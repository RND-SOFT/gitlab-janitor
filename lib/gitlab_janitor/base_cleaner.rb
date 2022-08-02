module GitlabJanitor
  class BaseCleaner

    class Model

      attr_reader :model

      def initialize(model)
        @model = model
      end

      def method_missing(method, *args, &block)
        super unless model.respond_to?(method)

        model.send(method, *args, &block)
      end

      def respond_to?(*args)
        model.send(:respond_to?, *args) || super
      end

      def respond_to_missing?(method_name, include_private = false)
        model.send(:respond_to_missing?, method_name, include_private) || super
      end

    end

    attr_reader :delay, :deadline, :logger

    def initialize(delay: 10, deadline: 1.second, logger: GitlabJanitor::Util.logger, **_args)
      @delay = delay
      @deadline = deadline
      @logger = logger.tagged(self.class.to_s)
    end

    def clean(remove: false)
      return nil if @cleaned_at && (::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - @cleaned_at) < @delay.seconds

      do_clean(remove: remove)

      @cleaned_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      true
    end

    def log_exception(text)
      yield
    rescue StandardError => e
      logger.error("Exception in #{text}: #{e}")
      logger.error e.backtrace
    end

  end
end

