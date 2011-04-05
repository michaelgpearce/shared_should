require 'helper'

class TestSharedShould < Test::Unit::TestCase
  # check that setup instance method is executed when setup is overridden
  def setup
    @setup_instance_method_executed = true
  end
  
  should "execute setup instance method" do
    assert @setup_instance_method_executed
  end
  
  # test class as context
  share_setup "for a true value in class" do
    assert @setup_instance_method_executed # setup instance method should have been called first
    @class_value = true
  end
  
  share_should "be a valid should test in class" do
    assert @class_value
  end
  
  share_context "for a valid context test in class" do
    should "have a true value" do
      assert @class_value
    end
  end
  
  use_setup "for a true value in class"
  
  use_should "be a valid should test in class"
  
  use_context "for a valid context test in class"
  
  
  context ".share_context" do
    context "without params" do
      share_context "for a valid value" do
        setup do
          @context_value = true
        end
      
        should "have true value" do
          assert @value
        end
      
        should "call setup in shared context" do
          assert @context_value
        end
      end
      
      context "with value in setup" do
        setup do
          @value = true
        end
  
        use_context "for a valid value"
      end
    
      context "with value in initializer" do
        setup("with a true value") { @value = true }.use_context("for a valid value")
      end
    end
    
    context "with params" do
      setup do
        @value = true
      end
      
      share_context "for a valid specified value" do
        setup do |value|
          @expected_value = value
          @context_value = true
        end
        
        should "have specified value" do |value|
          assert_equal value, @value
        end
        
        should "setup @expected_value" do |value|
          assert_equal value, @expected_value
        end
        
        should "call setup in shared context" do
          assert @context_value
        end
      end
      
      use_context("for a valid specified value").given("true") { true }
      
      context "with chaining" do
        share_context "for a chained value" do
          should "chain initialization block and be with params" do |value|
            assert @chain
            assert value
          end
        end
        
        setup("for an initialization chain") { @chain = true }.use_context("for a chained value").given("true") { true }
      end
    end
  end
  
  context ".share_should" do
    context "without params" do
      share_should "be a true value" do
        assert @value
      end
      
      context "with value in setup" do
        setup do
          @value = true
        end
        
        use_should "be a true value"
      end
      
      context "when value in initializer" do
        setup("with true value") { @value = true }.use_should("be a true value")
      end
      
      context "with value in initializer" do
        setup("with true value") { @value = true }.use_should("be a true value")
      end
    end
    
    context "with params" do
      setup do
        @value = true
      end
      
      share_should "be a valid specified value" do |value|
        assert_equal value, @value
      end
      
      use_should("be a valid specified value").given("true") { true }
      
      context "with chaining" do
        share_should "be a valid specified value" do |value|
          assert @chain
          assert value
        end
        
        setup("with initialization chain") { @chain = true }.use_should("be a valid specified value").given("true") { true }
      end
    end
  end
  
  context ".share_setup" do
    context "without params" do
      context "without initialization block" do
        setup do
          # value that will be overwritten
          @value = false
        end
  
        share_setup "for true value" do
          @value = true
        end
  
        use_setup("for true value")
  
        should "have a true value from shared setup" do
          assert @value
        end
      end
      
      context "with initialization block" do
        setup do
          # value that will be overwritten
          @value = false
        end
  
        share_setup "for value" do
          @value = @initialization_value
        end
  
        setup("with initialization true value") { @initialization_value = true }.use_setup("for value")
  
        should "have a true value from shared setup" do
          assert @value
        end
      end
    end
    
    context "with param block" do
      share_setup "for value" do |value|
        @value = value
      end
      
      context "with shared setup value" do
        setup do
          # value that will be overwritten
          @value = false
        end
      
        use_setup("for value").given("true") { true }
      
        should "have a true value from shared setup" do
          assert @value
        end
      end
      
      context "with chaining" do
        setup do
          @chain = nil
          @value = nil
        end
        
        share_setup "for value" do |value|
          @value = value
        end
        
        use_setup("for value").given("true") { true }.setup("with chain true") { @chain = true }
        
        should "have used share with chain and params" do
          assert @chain
          assert @value
        end
      end
    end
  end
  
  context "context directly under test class" do
    share_setup "for a true value" do
      @value = true
    end
    
    share_should "be a valid should test" do
      assert @value
    end
    
    share_context "for a valid context test" do
      should "have a true value" do
        assert @value
      end
    end
  
    use_setup "for a true value"
    
    use_should "be a valid should test"
    
    use_context "for a valid context test"
  end
  
  context "chaining" do
    context "with ordering verification" do
      setup do
        @count = 0
      end
      
      share_setup "for shared setup 1" do |count|
        assert_equal 1, @count
        assert_equal count, @count
        @count += 1
      end
      
      share_setup "for shared setup 2" do |count|
        assert_equal 3, @count
        assert_equal count, @count
        @count += 1
      end
      
      share_should "be valid shared should" do |count|
        assert_equal 7, @count
        assert_equal count, @count
      end
      
      use_setup("for shared setup 1").given("increment 1") { assert_equal 0, @count; @count += 1 }.
        use_setup("for shared setup 2").given("increment 2") { assert_equal 2, @count; @count += 1 }.
        setup("with setup value 3") { assert_equal 4, @count; @count += 1 }.
        setup("with setup value 4") { assert_equal 5, @count; @count += 1 }.
        use_should("be valid shared should").given("increment 3") { assert_equal 6, @count; @count += 1 }
    end
    
    context "with should" do
      setup("for true value") { @value = true }.should("be true value") do
        assert @value
      end
    end
    
    context "with shared should" do
      share_should "be true value" do |value|
        assert @value
        assert value
      end
      
      setup("for true value") { @value = true }.use_should("be true value").given("true") { true }
    end
    
    context "with context" do
      setup("for true value") { @value = true }.context do
        should "be true value" do
          assert @value
        end
      end
    end
    
    context "with shared context" do
      share_context "for a shared context" do
        should "have a true value" do |value|
          assert @value
          assert value
        end
      end
      
      setup("for true value") { @value = true }.use_context("for a shared context").given("true") { true }
    end
  end
  
  context "with unusual characters in name" do
    name = "-- \\ ' \" --"
    
    share_context name do
      should "be valid" do
        assert true
      end
    end
    
    use_context name
    
    share_should name do
      assert true
    end
    
    use_should name
    
    share_setup name do
      assert true
    end
    
    use_setup name
  end
  
  # ensure should macros work
  def self.should_be_a_valid_macro
    should "be a valid macro" do
      assert true
    end
  end
  
  context "shoulda macro" do
    should_be_a_valid_macro
  end
  
  # ensure NoMethodError called when method not found
  begin
    invalid_method do
    end
    raise "Should have raised a NoMethodError"
  rescue NoMethodError
    # successfully raised NoMethodError
  end
  
  context "NoMethodError check" do
    begin
      invalid_method do
      end
      raise "Should have raised a NoMethodError"
    rescue NoMethodError
      # successfully raised NoMethodError
    end
  end
  
  context "expected methods" do
    should "have expected methods in test" do
      # ensure test methods are created
      expected_method_names = [
          "test: .share_should without params with value in setup should be a true value. ",
          "test: .share_context without params with value in setup for a valid value should call setup in shared context. ",
          "test: .share_context without params with value in initializer with a true value for a valid value should have true value. ",
          "test: for a valid context test in class should have a true value. ",
          "test: .share_should with params should be a valid specified value given true. ",
          "test: .share_should without params with value in initializer with true value should be a true value. ",
          "test: .share_should without params when value in initializer with true value should be a true value. ",
          "test: .share_should with params with chaining with initialization chain should be a valid specified value given true. ",
          "test: .share_setup with param block with shared setup value should have a true value from shared setup. ",
          "test: .share_context without params with value in initializer with a true value for a valid value should call setup in shared context. ",
          "test: .share_context with params with chaining for an initialization chain for a chained value given true should chain initialization block and be with params. ",
          "test:  should be a valid should test in class. ",
          "test: .share_setup without params with initialization block should have a true value from shared setup. ",
          "test: .share_context without params with value in setup for a valid value should have true value. ",
          "test: shoulda macro should be a valid macro. ",
          "test: .share_setup with param block with chaining should have used share with chain and params. ",
          "test: .share_context with params for a valid specified value given true should call setup in shared context. ",
          "test: chaining with ordering verification for shared setup 1 given increment 1 for shared setup 2 given increment 2 with setup value 3 with setup value 4 should be valid shared should given increment 3. ",
          "test: .share_context with params for a valid specified value given true should setup @expected_value. ",
          "test: .share_context with params for a valid specified value given true should have specified value. ",
          "test: chaining with shared should for true value should be true value given true. ",
          "test: chaining with should for true value should be true value. ",
          "test: chaining with context for true value should be true value. ",
          "test: expected methods should have expected methods in test. ",
          "test: chaining with shared context for true value for a shared context given true should have a true value. ",
          "test: context directly under test class should be a valid should test. ",
          "test: context directly under test class for a valid context test should have a true value. ",
          "test: .share_setup without params without initialization block should have a true value from shared setup. ",
          "test: SharedShould should execute setup instance method. ",
          "test: with unusual characters in name -- \\ ' \" -- should be valid. ",
          "test: with unusual characters in name should -- \\ ' \" --. "
      ].inject({}) do |hash, expected_method_name|
        hash[expected_method_name] = true
        hash
      end
      actual_method_names = self.class.suite.tests.inject({}) do |hash, test_case|
        hash[test_case.method_name] = true
        hash
      end
  
      actual_methods_not_found = []
      actual_method_names.each do |method_name, value|
        actual_methods_not_found << method_name unless expected_method_names.include?(method_name)
      end
      assert_equal [], actual_methods_not_found, "Unknown methods exist in the test suite"
      
      expected_methods_not_found = []
      expected_method_names.each do |method_name, value|
         expected_methods_not_found << method_name unless actual_method_names.include?(method_name)
      end
      assert_equal [], expected_methods_not_found, "Unknown methods exist in the list of expected tests"
      
    end
  end
end
