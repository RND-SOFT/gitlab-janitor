require 'logger'
require 'active_support/all'

module GitlabJanitor
  class Util

    TERM_SIGNALS = %w[INT TERM].freeze

    class << self

      def exiting?
        $exiting
      end

      def exit!
        $exiting = true
      end

      def logger
        $logger ||= ActiveSupport::TaggedLogging.new(Logger.new(STDOUT)).tap do |logger|
          logger.level = ENV.fetch('LOG_LEVEL', Logger::INFO)
          formatter = Logger::Formatter.new
          formatter.extend ActiveSupport::TaggedLogging::Formatter
          logger.formatter = formatter
        end
      end

      def setup
        STDOUT.sync = true
        STDERR.sync = true

        initialize_signal_handlers

        String.class_eval do
          def to_bool
            return true   if self == true   || self =~ (/(true|t|yes|y|1)$/i)
            return false  if self == false  || self.blank? || self =~ (/(false|f|no|n|0)$/i)

            raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
          end
        end
      end

      def initialize_signal_handlers
        TERM_SIGNALS.each do |sig|
          trap(sig) do |*_args|
            TERM_SIGNALS.each do |s|
              trap(s) do |*_args|
                warn 'Forcing exit!'
                Kernel.exit!(1)
              end
            end

            STDOUT.puts "Caught signal[#{sig}]: exiting...."
            GitlabJanitor::Util.exit!
          end
        end
      end

    end

  end
end

