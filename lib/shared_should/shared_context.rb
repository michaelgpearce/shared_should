module SharedShould::SharedContext
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
            shared_proxy.share_execute
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
      (shared_proxies << SharedShould::SharedProxy.new(self)).last
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
