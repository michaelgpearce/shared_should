require 'helper'

# Create a subclass for some shares
class SubclassTestCase < Test::Unit::TestCase
  should "have a test" do
    assert true
  end
end

# re-open Test::Unit::TestCase class for some shares
class Test::Unit::TestCase
  share_should "be a true value for shared should helper" do
    assert @value
  end
  
  share_context "for a true value for shared context helper" do
    should "be true value" do
      assert @value
    end
  end
  
  share_setup "for a true value for shared setup helper" do
    @value = true
  end
  
end

class TestSharedShouldHelper < SubclassTestCase
  context "with helper module" do
    context "with shared should helper" do
      setup do
        @value = true
      end
      
      use_should "be a true value for shared should helper"
    end
    
    context "with shared context helper" do
      setup do
        @value = true
      end
      
      use_context "for a true value for shared context helper"
    end
    
    context "with share_setup helper" do
      use_setup "for a true value for shared setup helper"
      
      should "be true value" do
        assert @value
      end
    end
  end
end
