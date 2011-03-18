require 'shoulda'

class Shoulda::Context
  alias :method_missing_without_shared_method_check :method_missing
  def method_missing(method, *args, &blk)
    current_context = self
    while current_context.kind_of?(Shoulda::Context) || current_context < Test::Unit::TestCase do
      if Test::Unit::TestCase.shared_context_block_owner(current_context).shared_context_blocks[method.to_s]
        return current_context.send(method, args[0], self, &blk)
      end
      break unless current_context.kind_of?(Shoulda::Context)
      current_context = current_context.parent
    end
    method_missing_without_shared_method_check(method, *args, &blk)
  end
end

class Test::Unit::TestCase
  attr_accessor :shared_value
  attr_accessor :shared_name
  @@shared_proxies_executed = {}
  @@setup_blocks = {}

  class << self
    # these methods need to be aliased for both the test class and the should context
    alias_method :suite_without_shared_should_execute, :suite
  end
  
  def self.suite
    # assuming 'suite' is called before executing any tests - may be a poor assumption. Find something better?
    unless @@shared_proxies_executed[self]
      shared_proxies.each do |shared_proxy|
        shared_proxy.execute(self)
      end
      @@shared_proxies_executed[self] = true
    end
    
    suite_without_shared_should_execute
  end
  
  def self.shared_context_block_owner(context_or_test_class)
    return context_or_test_class.kind_of?(Shoulda::Context) ? context_or_test_class : Test::Unit::TestCase
  end

  def execute_class_shared_setups_if_not_executed
    if !@shared_setups_executed
      @shared_setups_executed = true
      (@@setup_blocks[self.class] || []).each do |setup_block|
        setup_block.bind(self).call
      end
    end
  end

  def self.setup(&setup_block)
    @@setup_blocks[self] = [] unless @@setup_blocks[self]
    @@setup_blocks[self] << setup_block
  end
  
  def setup_shared_values(name, initialization_block)
    self.shared_value = initialization_block.nil? ? nil : initialization_block.bind(self).call
    self.shared_name = name
  end
  
  def call_block_with_shared_value(test_block)
    execute_class_shared_setups_if_not_executed
    if test_block.arity == 1
      # check arity of 1 before checking if value is an array. If one parameter, never treat the shared_value as variable args
      test_block.bind(self).call(self.shared_value)
    elsif self.shared_value.class == Array && test_block.arity == self.shared_value.length
      test_block.bind(self).call(*self.shared_value)
    else
      test_block.bind(self).call()
    end
  end
end

module Shoulda::SharedContext
  # class methods for Test::Unit::TestCase
  def self.extended(klass)
    class << klass
      # these methods need to be aliased for both the test class and the should context
      alias_method :context_without_shared_proxies_executing, :context
      alias_method :should_without_param_support, :should
      alias_method :setup_without_param_support, :setup
    end
    
    klass.extend(SharedContextMethods)
  end
  
  # instance methods for Shoulda::Context
  def self.included(klass)
    klass.class_eval do
      # these methods need to be aliased for both the test class and the should context
      alias :context_without_shared_proxies_executing :context
      alias :should_without_param_support :should
      alias :setup_without_param_support :setup
      
      # remove any methods we are going to define with our included module
      SharedContextMethods.instance_methods.each do |method_name|
        remove_method method_name if method_defined? method_name
      end
    end
    
    klass.send(:include, SharedContextMethods)
  end
  
  module SharedContextMethods
    def shared_proxies
      @shared_proxies ||= []
    end
  
    def use_should(shared_name)
      shared_proxy = Shoulda::SharedProxy.new(shared_name)
      shared_proxies << shared_proxy
      return shared_proxy
    end
    
    def use_context(shared_name)
      shared_proxy = Shoulda::SharedProxy.new(shared_name)
      shared_proxies << shared_proxy
      return shared_proxy
    end
    
    def use_setup(shared_name)
      shared_proxy = Shoulda::SharedProxy.new(shared_name)
      shared_setup_block = find_shared_setup_block(shared_name)
      setup do
        if initialization_block = shared_proxy.initialization_block
          setup_shared_values(shared_proxy.description, shared_proxy.initialization_block)
        end
        call_block_with_shared_value(shared_setup_block)
      end
      return shared_proxy
    end
  
    def context(name = nil, &block)
      if block
        shared_proxies_executing_block = Proc.new do
          block.bind(self).call
        
          shared_proxies.each do |shared_proxy|
            shared_proxy.execute(self)
          end
        end
        shared_proxies_executing_block.bind(eval("self", block.binding))
        context_without_shared_proxies_executing(name, &shared_proxies_executing_block)
      end
    end

    def should(name = nil, options = {}, &block)
      if block.nil?
        should_without_param_support(name, options)
      else
        should_without_param_support(name, options) do
          call_block_with_shared_value(block)
        end
      end
    end

    def setup(&block)
      if block.nil?
        setup_without_param_support()
      else
        setup_without_param_support() do
          call_block_with_shared_value(block)
        end
      end
    end
  
    # deprecated
    def shared_context_should(shared_context_name, &shared_context_block)
      share_context(shared_context_name, &shared_context_block)
    end

    def share_context(shared_context_name, &shared_context_block)
      wrapping_shared_context_block = Proc.new do
        context shared_context_name do
          merge_block(&shared_context_block)
        end
      end

      do_shared_context(shared_context_name, shared_context_for_block(shared_context_block), &wrapping_shared_context_block)
    end

    # deprecated
    def shared_should(shared_should_name, &shared_should_block)
      share_should(shared_should_name, &shared_should_block)
    end

    def share_should(shared_should_name, &shared_should_block)
      shared_context_block = Proc.new do
        should shared_should_name do
          call_block_with_shared_value(shared_should_block)
        end
      end

      do_shared_context(shared_should_name, shared_context_for_block(shared_should_block), &shared_context_block)
    end

    # deprecated
    def shared_setup(shared_name, &setup_block)
      shared_setup_block = Proc.new do
        call_block_with_shared_value(setup_block)
      end

      do_shared_setup(shared_name, shared_context_for_block(setup_block), &shared_setup_block)
    end

    def share_setup(shared_name, &setup_block)
      current_context = eval('self', setup_block.binding)
      Test::Unit::TestCase.shared_context_block_owner(current_context).shared_setup_blocks[shared_name] = setup_block
    end

    def shared_context_blocks
       @shared_context_blocks ||= {}
    end

    def shared_should_blocks
       @shared_should_blocks ||= {}
    end

    def shared_setup_blocks
       @shared_setup_blocks ||= {}
    end

    private

    def shared_context_for_block(shared_block)
      eval("self", shared_block.binding)
    end

    def do_shared_context(shared_context_name, destination_context, &shared_context_block)
      do_shared_helper(shared_context_name, destination_context, :should, :merge_shared_context, &shared_context_block)
    end

    def merge_shared_context(shared_context_block, caller_context, name, initialization_block)
      name = '' if name.nil?

      caller_context.context name do
        setup do
          setup_shared_values(name, initialization_block)
        end

        merge_block(&shared_context_block)
      end
    end

    def do_shared_setup(shared_setup_name, destination_context, &shared_setup_block)
      do_shared_helper(shared_setup_name, destination_context, :setup, :merge_shared_setup, &shared_setup_block)
    end

    def merge_shared_setup(shared_setup_block, caller_context, name, setup_block)
      # note: the binding for the block of the TestCase's setup method is not an instance of the TestCase - its the TestCase class.
      # Handle the TestCase class by chaining it to the setup method.
      if caller_context == self
        @@shared_setup_alias_index = 0 unless defined?(@@shared_setup_alias_index)
        @@shared_setup_alias_index += 1
        with_method = :"setup_with_shared_setup_#{@@shared_setup_alias_index}"
        without_method = :"setup_without_shared_setup_#{@@shared_setup_alias_index}"
        caller_context.send(:alias_method, without_method, :setup)
        caller_context.send(:define_method, with_method) do
          send(without_method)
          setup_shared_values(name, setup_block)
          shared_setup_block.bind(self).call
        end
        caller_context.send(:alias_method, :setup, with_method)
      else
        caller_context.setup do
          setup_shared_values(name, setup_block)
          shared_setup_block.bind(self).call
        end
      end
    end

    def do_shared_helper(shared_name, destination_context, method_prefix, merge_method, &shared_setup_block)
      method_name = shared_method_name(method_prefix, shared_name)
      Test::Unit::TestCase.shared_context_block_owner(destination_context).shared_context_blocks[method_name] = shared_setup_block

      # Ruby 1.8 workaround for define_method with a block
      # http://coderrr.wordpress.com/2008/10/29/using-define_method-with-blocks-in-ruby-18/
      eval <<-EOM
        def destination_context.#{method_name}(name = nil, context = self, &setup_block)
          #{merge_method}(Test::Unit::TestCase.shared_context_block_owner(self).shared_context_blocks['#{method_name}'], context, name, block_given? ? setup_block : nil)
        end
      EOM
    end

    def shared_method_name(method_prefix, context_name)
      "#{method_prefix}_#{context_name.downcase.gsub(' ', '_').gsub(/[^_A-Za-z0-9]/, '')}"
    end

  private
  
    def find_shared_setup_block(shared_name)
      current_context = self
      while current_context.kind_of?(Shoulda::Context) || current_context < Test::Unit::TestCase do
        if shared_setup_block = Test::Unit::TestCase.shared_context_block_owner(current_context).shared_setup_blocks[shared_name]
          return shared_setup_block
        end
        raise "Unable to find share_setup('#{shared_name}')" if current_context.kind_of?(Class)
        break unless current_context.kind_of?(Shoulda::Context)
        current_context = current_context.parent
      end
      raise "Unable to find share_setup('#{shared_name}')"
    end
  end
end

class Shoulda::Context
  include Shoulda::SharedContext
end

class Test::Unit::TestCase
  extend Shoulda::SharedContext
end


class Shoulda::SharedProxy
  attr_accessor :shared_name, :description, :initialization_blocks
  
  def initialize(shared_name)
    self.shared_name = shared_name
    self.initialization_blocks = []
  end
  
  def with(description = nil, &initialization_block)
    with_helper("with", description, &initialization_block)
  end
  
  def when(description = nil, &initialization_block)
    with_helper("when", description, &initialization_block)
  end
  
  def given(description = nil, &initialization_block)
    with_helper("given", description, :disable_and => true, &initialization_block)
  end
  
  def execute(context)
    method_name = context.send(:shared_method_name, :should, shared_name)
    context.send(method_name, description, &initialization_block)
  end
  
  def initialization_block
    blocks = initialization_blocks
    return Proc.new do
      blocks.collect {|block| block.bind(self).call if block}.last
    end
  end
  
  private
  
  def with_helper(conditional, description, options = {}, &initialization_block)
    if description
      and_text = options[:disable_and] ? ' ' : ' and '
      self.description = "#{self.description}#{self.description.nil? ? nil : and_text}#{conditional} #{description}"
    end
    self.initialization_blocks << initialization_block
    return self
  end
end
