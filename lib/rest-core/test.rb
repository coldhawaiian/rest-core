
require 'fiber'
require 'em-http-request'
require 'rest-core'

require 'webmock'
require 'muack'
require 'bacon'

# for testing lighten (serialization)
require 'yaml'

include Muack::API
include WebMock::API
WebMock.disable_net_connect!(:allow_localhost => true)
Bacon.summary_on_exit

module Kernel
  def eq? rhs
    self == rhs
  end

  def lt? rhs
    self < rhs
  end

  def with_img
    f = Tempfile.new(['img', '.jpg'])
    n = File.basename(f.path)
    f.write('a'*10)
    f.rewind
    yield(f, n)
  ensure
    f.close!
  end
end
