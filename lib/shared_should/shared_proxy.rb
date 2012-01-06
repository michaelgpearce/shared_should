class SharedShould::SharedProxy
  attr_accessor :source_context, :setup_block_configs, :test_type, :test_block, :test_description, :current_action
  
  def initialize(source_context)
    self.setup_block_configs = []
    self.source_context = source_context
  end
  
  def setup(description = nil, &initialization_block)
    add_setup_block(:setup, description, &initialization_block)
  end
  
  def use_setup(share_name)
    add_setup_block(:use_setup, share_name, &source_context.find_shared_block(:setup, share_name))
  end
  
  # deprecated
  def with_setup(share_name)
    return use_setup(share_name)
  end
  
  # deprecated
  def with(share_name = nil, &initialization_block)
    return setup(share_name ? "with #{share_name}" : nil, &initialization_block)
  end

  # deprecated
  def when(share_name = nil, &initialization_block)
    return setup(share_name ? "when #{share_name}" : nil, &initialization_block)
  end

  def given(description = nil, &initialization_block)
    valid_share_types = [:use_setup, :use_should, :use_context]
    @failed = true and raise ArgumentError, "'given' can only appear after #{valid_share_types.join(', ')}" unless valid_share_types.include?(current_action)
    
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
    add_test_block(:use_should, share_name, &source_context.find_shared_block(:should, share_name))
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
    add_test_block(:use_context, share_name, &source_context.find_shared_block(:context, share_name))
  end
  
  def share_execute
    return if @failed
    
    shared_proxy = self
    if test_type == :should || test_type == :context || test_type == :use_should || test_type == :use_context
      # create a new context for setups and should/context
      source_context.context setup_block_configs_description do
        setup_without_param_support do
          shared_proxy.setup_block_configs.each do |config|
            call_block_config(config)
          end
        end
        
        # share_description called when creating test names
        self.instance_variable_set("@share_description", shared_proxy.send(:test_description))
        def self.share_description; @share_description; end
        merge_block(&shared_proxy.test_block)
      end
    else
      # call setups directly in this context
      source_context.setup_without_param_support do
        shared_proxy.setup_block_configs.each do |config|
          call_block_config(config)
        end
      end
    end
  end
  
private

  def setup_block_configs_description
    @setup_block_configs_description
  end
  
  def add_test_block(test_type, description, &test_block)
    @failed = true and raise ArgumentError, 'Only a single should or context can be chained' if self.test_type
    
    self.test_type = test_type
    self.current_action = test_type
    self.test_description = description
    self.test_block = test_block
    return self
  end

  def add_setup_block(action, description, &block)
    if test_type
      #@failed = true and raise ArgumentError, "'#{action}' may not be applied" unless action == :given
      # add final given description to test description
      self.test_description = "#{test_description} #{description}" if description
      description = nil
    end
    
    setup_block_config = {:block => block, :action => action, :description => description}
    if action == :given and (current_action == :setup || current_action == :use_setup)
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
