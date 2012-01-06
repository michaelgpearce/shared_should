$: << File.expand_path(File.join(File.dirname(__FILE__), 'shared_should'))
require 'shoulda'

module SharedShould; end

require 'test_class_helper'
require 'shared_context'
require 'shared_proxy'
require 'test_unit_hooks'
