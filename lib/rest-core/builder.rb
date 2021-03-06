
require 'rest-core/client'
require 'rest-core/wrapper'

class RestCore::Builder
  include RestCore
  include Wrapper

  def self.default_engine
    @default_engine ||= RestCore::Auto
  end

  def self.client *attrs, &block
    new(&block).to_client(*attrs)
  end

  def to_client *attrs
    fields = members + attrs
    struct = if fields.empty?
               Struct.new(nil)
             else
               Struct.new(*fields.uniq)
             end
    client = Class.new(struct)
    client.const_set('Struct', struct)
    client.send(:include, Client)
    class << client; attr_reader :builder; end
    client.instance_variable_set(:@builder, self)
    client
  end

  def initialize &block
    @engine    = nil
    @middles ||= []
    instance_eval(&block) if block_given?
  end
end
