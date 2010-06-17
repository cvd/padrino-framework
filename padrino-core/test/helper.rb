ENV['PADRINO_ENV'] = 'test'
PADRINO_ROOT = File.dirname(__FILE__) unless defined? PADRINO_ROOT

require File.expand_path('../../../load_paths', __FILE__)
require 'padrino-core'
require 'test/unit'
require 'riot'
require 'rack/test'
require 'rack'

module Kernel
  # Silences the output by redirecting to stringIO
  # silence_logger { ...commands... } => "...output..."
  def silence_logger(&block)
    $stdout = log_buffer = StringIO.new
    block.call
    $stdout = STDOUT
    log_buffer.string
  end
  alias :silence_stdout :silence_logger

  def silence_warnings
    old_verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old_verbose
  end unless respond_to?(:silence_warnings)

end

class Class
  # Allow assertions in request context
  include Test::Unit::Assertions
end

Riot.reporter = Riot::DotMatrixReporter

class Riot::Context
  def assert_match(matchee, pattern)
    pattern = pattern.is_a?(String) ? Regexp.new(Regexp.escape(pattern)) : pattern
    asserts("#{matchee} matches #{pattern}") { matchee =~ pattern}
  end

  # Asserts that a file matches the pattern
  def assert_match_in_file(pattern, file)
    File.exist?(file) ? assert_match(File.read(file), pattern) : assert_file_exists(file)
  end
end

class Riot::Situation
  include Rack::Test::Methods

  # Sets up a Sinatra::Base subclass defined with the block
  # given. Used in setup or individual spec methods to establish
  # the application.
  def mock_app(base=Padrino::Application, &block)
    @app = Sinatra.new(base, &block)
  end

  def app
    Rack::Lint.new(@app)
  end

  # Delegate other missing methods to response.
  def method_missing(name, *args, &block)
    if response && response.respond_to?(name)
      response.send(name, *args, &block)
    else
      super(name, *args, &block)
    end
  end

  alias :response :last_response

  def create_template(name, content, options={})
    FileUtils.mkdir_p(File.dirname(__FILE__) + "/views")
    FileUtils.mkdir_p(File.dirname(__FILE__) + "/views/layouts")
    path  = "/views/#{name}"
    path += ".#{options.delete(:locale)}" if options[:locale].present?
    path += ".#{options[:format]}" if options[:format].present?
    path += ".erb" unless options[:format].to_s =~ /haml|rss|atom/
    path += ".builder" if options[:format].to_s =~ /rss|atom/
    file  = File.dirname(__FILE__) + path
    File.open(file, 'w') { |io| io.write content }
    file
  end
  alias :create_view   :create_template
  alias :create_layout :create_template

  def remove_views
    FileUtils.rm_rf(File.dirname(__FILE__) + "/views")
  end

  def with_template(name, content, options={})
    # Build a temp layout
    template = create_template(name, content, options)
    yield
  ensure
    # Remove temp layout
    File.unlink(template) rescue nil
    remove_views
  end
  alias :with_view   :with_template
  alias :with_layout :with_template
end