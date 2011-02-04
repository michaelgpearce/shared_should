require 'helper'

# re-open ActiveSupport::TestCase class for some shares
class SubclassTestCase < Test::Unit::TestCase
  shared_should "have true value for shared should helper" do
    assert @value
  end
  
  shared_should_be "a true value for shared should helper" do
    assert @value
  end
  
  should "have a test" do
    assert true
  end
end

# re-open Test::Unit::TestCase class for some shares
class Test::Unit::TestCase
  shared_context_should "be valid for shared context helper" do
    should "be true value" do
      assert @value
    end
  end
  
  shared_context_for "a true value for shared context helper" do
    should "be true value" do
      assert @value
    end
  end
  
  shared_setup "for shared setup helper" do
    @value = true
  end
  
  shared_setup_for "a true value for shared setup helper" do
    @value = true
  end
end

class TestSharedShouldHelper < SubclassTestCase
  context "with helper module" do
    context "with shared should helper" do
      setup do
        @value = true
      end
      
      should_have_true_value_for_shared_should_helper
      
      should_be("a true value for shared should helper")
    end
    
    context "with shared context helper" do
      setup do
        @value = true
      end
      
      should_be_valid_for_shared_context_helper
      
      should_be("a true value for shared context helper")
    end
    
    context "with shared_setup helper" do
      setup_for_shared_setup_helper
      
      should "be true value" do
        assert @value
      end
    end
    
    context "with shared_setup_for helper" do
      setup_for("a true value for shared setup helper")
      
      should "be true value" do
        assert @value
      end
    end
  end
end
