require 'shoulda'

class Test::Unit::TestCase
  attr_accessor :shared_value
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
        shared_proxy.execute
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
  
  def setup_shared_value(initialization_block)
    self.shared_value = initialization_block.nil? ? nil : initialization_block.bind(self).call
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
  
  def call_block_shared_value(test_block)
    self.shared_value = call_block_with_shared_value(test_block)
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
      return add_shared_proxy.use_should(shared_name)
    end
    
    def use_context(shared_name)
      return add_shared_proxy.use_context(shared_name)
    end
    
    def use_setup(shared_name)
      return add_shared_proxy.use_setup(shared_name)
    end
  
    def setup(name = nil, &block)
      return add_shared_proxy.setup(name, &block)
    end
  
    def context(name = nil, &block)
      if block
        shared_proxies_executing_block = Proc.new do
          block.bind(self).call
        
          shared_proxies.each do |shared_proxy|
            shared_proxy.execute
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

    def share_context(shared_context_name, &shared_context_block)
      wrapping_shared_context_block = Proc.new do
        context share_description do
          merge_block(&shared_context_block)
        end
      end

      Test::Unit::TestCase.shared_context_block_owner(shared_context_for_block(shared_context_block)).shared_context_blocks[shared_context_name] = wrapping_shared_context_block
    end

    def share_should(shared_should_name, &shared_should_block)
      shared_context_block = Proc.new do
        should share_description do
          call_block_with_shared_value(shared_should_block)
        end
      end

      Test::Unit::TestCase.shared_context_block_owner(shared_context_for_block(shared_should_block)).shared_should_blocks[shared_should_name] = shared_context_block
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

    def find_shared_block(share_type, shared_name)
      current_context = self
      while current_context.kind_of?(Shoulda::Context) || current_context < Test::Unit::TestCase do
        if shared_block = Test::Unit::TestCase.shared_context_block_owner(current_context).send("shared_#{share_type}_blocks")[shared_name]
          return shared_block
        end
        raise "Unable to find share_#{share_type}('#{shared_name}')" if current_context.kind_of?(Class)
        break unless current_context.kind_of?(Shoulda::Context)
        current_context = current_context.parent
      end
      raise "Unable to find share_#{share_type}('#{shared_name}')"
    end
    
  private
  
    def add_shared_proxy
      (shared_proxies << Shoulda::SharedProxy.new(self)).last
    end

    def shared_context_for_block(shared_block)
      eval("self", shared_block.binding)
    end

    def merge_shared_context(shared_context_block, caller_context, name, initialization_block)
      name = '' if name.nil?

      caller_context.context name do
        setup do
          setup_shared_value(initialization_block)
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
          setup_shared_value(setup_block)
          shared_setup_block.bind(self).call
        end
        caller_context.send(:alias_method, :setup, with_method)
      else
        caller_context.setup do
          setup_shared_value(setup_block)
          shared_setup_block.bind(self).call
        end
      end
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
  attr_accessor :source_context, :setup_block_configs, :test_type, :test_block, :test_description, :current_action
  
  def initialize(source_context)
    self.setup_block_configs = []
    self.source_context = source_context
  end
  
  def setup(description = nil, &initialization_block)
    add_setup_block(:setup, description, &initialization_block)
  end
  
  def use_setup(share_name)
    add_setup_block(:setup, share_name, &source_context.find_shared_block(:setup, share_name))
  end
  
  def given(description = nil, &initialization_block)
    # TODO
    # valid_share_types = [:use_setup, :use_should, :use_context]
    # raise "'given' can only appear after #{valid_share_types.join(', ')} ---- #{current_action}" unless valid_share_types.include?(current_action)
    add_setup_block(:given, description ? "given #{description}" : nil, &initialization_block)
  end
  
  def should(description = nil, options = {}, &should_block)
    shared_context_block = Proc.new do
      should share_description do
        call_block_with_shared_value(should_block)
      end
    end
    add_test_block(:should, description, &shared_context_block)
  end
  
  def use_should(share_name)
    add_test_block(:should, share_name, &source_context.find_shared_block(:should, share_name))
  end
  
  def context(description = nil, &context_block)
    shared_context_block = Proc.new do
      context share_description do
        merge_block(&context_block)
      end
    end
    add_test_block(:context, description, &shared_context_block)
  end
  
  def use_context(share_name)
    add_test_block(:context, share_name, &source_context.find_shared_block(:context, share_name))
  end
  
  def execute
    shared_proxy = self
    if test_type == :should || test_type == :context
      # create a new context for setups and should/context
      source_context.context setup_block_configs_description do
        setup_without_param_support do
          shared_proxy.setup_block_configs.each do |config|
            call_block_shared_value(config[:block])
          end
        end
        
        # share_description called when creating test names
        eval("def share_description; #{shared_proxy.send(:escaped_test_description)}; end")
        merge_block(&shared_proxy.test_block)
      end
    else
      # call setups directly in this context
      source_context.setup_without_param_support do
        shared_proxy.setup_block_configs.each do |config|
          call_block_shared_value(config[:block])
        end
      end
    end
  end
  
private

  def escaped_test_description
    test_description.nil? ? 'nil' : "'#{test_description.gsub('\\', '\\\\\\').gsub("'", "\\\\'")}'"
  end
  
  def setup_block_configs_description
    @setup_block_configs_description
  end
  
  def add_test_block(test_type, description, &test_block)
    raise 'Only a single should or context can be chained' if self.test_type
    
    self.current_action = test_type
    self.test_type = test_type
    self.test_description = description
    self.test_block = test_block
    return self
  end

  def add_setup_block(action, description, &block)
    if test_type
      raise "'#{action}' may not be applied" unless action == :given
      # add final given description to test description
      self.test_description = "#{test_description} #{description}" if description
      description = nil
    end
    
    setup_block_config = {:block => block, :action => action, :description => description}
    if action == :given and current_action == :setup
      setup_block_configs.insert(-2, setup_block_config)
    else
      setup_block_configs << setup_block_config
    end
    if description
      @setup_block_configs_description = "#{@setup_block_configs_description}#{' ' if @setup_block_configs_description}#{description}"
    end
    
    self.current_action = action
    return self
  end
end
