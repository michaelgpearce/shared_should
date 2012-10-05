# Ruby 1.9 with MiniTest
if defined?(MiniTest::Unit::TestCase)
  class MiniTest::Unit::TestCase
    class << self
      # these methods need to be aliased for both the test class and the should context
      alias_method :test_methods_without_shared_should_execute, :test_methods
    end
    
    class_eval do
      include SharedShould::TestClassHelper
    end
  
    def self.test_methods
      # assuming 'test_methods' is called before executing any tests - may be a poor assumption. Find something better?
      execute_class_shared_proxies
    
      test_methods_without_shared_should_execute
    end
  end
end

# Ruby 1.8 without MiniTest
if defined?(Test::Unit::TestCase.suite)
  class Test::Unit::TestCase
    class << self
      # these methods need to be aliased for both the test class and the should context
      alias_method :suite_without_shared_should_execute, :suite
    end
    
    class_eval do
      include SharedShould::TestClassHelper
    end
    
    def self.suite
      # assuming 'suite' is called before executing any tests - may be a poor assumption. Find something better?
      execute_class_shared_proxies
    
      suite_without_shared_should_execute
    end
  end
end

class Test::Unit::TestCase
  extend SharedShould::SharedContext
end

if defined?(Shoulda::Context::Context)
  class Shoulda::Context::Context
    include SharedShould::SharedContext
  end
elsif defined?(Shoulda::Context)
  class Shoulda::Context
    include SharedShould::SharedContext
  end
end
