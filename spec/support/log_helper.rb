RSpec.configure do |config|
  config.before(:suite) do
    GitlabJanitor::Util.logger.level = ::Logger::WARN
  end
end

