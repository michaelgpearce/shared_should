# Shared Should - Share and reuse shoulds, contexts, and setups with Shoulda - easy, schmeasy.

Shared Should allows you to easily create reusable shoulds, contexts and setups with familiar looking Shoulda syntax. Inspired by Rspec's shared example groups for context reuse, Shared Should allows sharing of contexts, shoulds,
and setup blocks. Shared Should goes even further by allowing chaining and parameterization to fine-tune the usage of the shared functionality.

## Quick-Start Examples

Some quick examples to get you started using Shared Should. The domain of the examples is customers renting and purchasing textbooks - something like we do at  [BookRenter.com](http://www.bookrenter.com "BookRenter.com").

### Shared Should

Sharing shoulds is easy.

    context "Book" do
        context "with an in-stock book" do
            setup { @book = Book.new(:quantity => 1, :price => 10_00 }
            
            ### Define a shared should
            share_should "be available for checkout" { assert @book.available_for_checkout? }

            context "with a rentable book" do
                setup { @book.rentable = true }

                ### Use the "be available for checkout" share_should
                use_should "be available for checkout"
            end

            context "with a purchasable book" do
                setup { @book.purchasable = true }

                ### Use the "be available for checkout" share_should in this context too
                use_should "be available for checkout"
            end
            
            ### ...or DRY it with chaining
            setup("with a rentable book") { @book.rentable = true }.use_should("be available for checkout")
            setup("with a purchasable book") { @book.purchasable = true }.use_should("be available for checkout")
        end
    end

### Shared Setup

Sharing setups is easy, too.

    context "Book" do
        ### Define a shared setup
        share_setup "for an in-stock book" { @book = Book.new(:quantity => 1, :price => 10_00) }
        
        context "with an in-stock rentable book" do
            ### Use the shared setup here
            use_setup "for an in-stock book"
            
            ### Do some additional setup after the shared setup
            setup { @book.rentable = true }
            
            should "be available for checkout" { assert @book.available_for_checkout? }
        end
        
        context "with an in-stock purchasable book" do
            ### Use the shared setup again
            use_setup "for an in-stock book"
            
            setup { @book.purchasable = true }
            
            should "be available for checkout" { assert @book.available_for_checkout? }
        end
        
        ### ...or DRY it with chaining
        use_setup("for an in-stock book").
            setup("with a rentable book") { @book.rentable = true }.
            should "be available for checkout" { assert @book.available_for_checkout? }
        use_setup("for an in-stock book").
            setup("with a purchasable book") { @book.purchasable = true }.
            should "be available for checkout" { assert @book.available_for_checkout? }
    end
    
### Shared Context

Sharing whole contexts? Schmeasy!

    context "Book" do
        context "with an in-stock book" do
            setup { @book = Book.new(:quantity => 1, :price => 10_00) }
        
            ### Define a shared context
            share_context "for a book available for checkout" do
                should "be in stock" { assert @book.quantity > 0 }
                should "have a non-negative price" { assert @book.price > 0 }
                should "be rentable or purchasable" { assert @book.rentable || @book.purchasable }
            end
        
            context "with a rentable book" do
                setup { @book.rentable = true }
            
                ### Run the shoulds inside the shared context with a rentable book
                use_context "for a book available for checkout"
            end
        
            context "with a purchasable book" do
                setup { @book.purchasable = true }
            
                ### Run the shoulds inside the shared context again with a purchasable book
                use_context "for a book available for checkout"
            end
            
            ### ...or DRY it up by using .when and an initialization block
            setup("with a rentable book") { @book.rentable = true }.use_context("for a book available for checkout")
            setup("with a purchasable book") { @book.purchasable = true }.use_context("for a book available for checkout")
        end
    end

## More Information on Syntax and Usage

### Finding Your Share

Some rules:

* When <tt>use\_should</tt>, <tt>use\_context</tt> or <tt>use\_setup</tt> is invoked, it searches up the context hierarchy to find a matching shared definition.
* You can redefine your shares by using the same name. These shares will only be available in in the current and descendant contexts.
* Shares defined at the root (on your TestCase) are available in all contexts.

### Chaining

Shared Should provides powerful chaining capabilities.

Chained <tt>setup</tt>s and <tt>use\_setup</tt>s are applied to their parent context:

    context "Book" do
        share_setup "for an in-stock book" do
            @book = Book.new(:quantity => 1, :price => 10_00
        end

        context "with a rentable book" do
            use_setup("for an in-stock book").setup { @book.rentable = true }
            
            should "be available for checkout" { assert @book.available_for_checkout? }
        end
    end

Or chained <tt>setup</tt>s and <tt>use\_setup</tt>s can be chained to a <tt>should</tt>, <tt>use\_should</tt>, <tt>context</tt>, or <tt>use\_context</tt>:

    context "Book" do
        share_setup "for an in-stock book" do
            @book = Book.new(:quantity => 1, :price => 10_00
        end

        use_setup("for an in-stock book").
            setup("for a rentable book") { @book.rentable = true }.
            should("be available for checkout") { assert @book.available_for_checkout? }
    end

### Parameterizing Shares

Shared functions can also be parameterized using block parameters. This can be done for shared setups, shared shoulds, and the <tt>setup</tt>s and <tt>should</tt>s contained within a shared context. The value passed to the shared function is the return value of the <tt>given</tt> parameterization block. The below example parameterizes a shared setup.

    context "Book" do
        share_setup "for an in-stock book" do |rentable|
            @book = Book.new(:quantity => 1, :price => 10_00, :rentable => rentable, :purchasable => false)
        end

        context "with rentable book" do
            # the return value of the block is "true" which will be passed as the block parameter "rentable"
            use_setup("for an in-stock book").given { true }
            
            should "be available for checkout" { assert @book.available_for_checkout? }
        end
    end

Here is a parameterized shared should.

    context "Book" do
        context "with in-stock book" do
            setup { @book = Book.new(:quantity => 1) }
        
            share_should "be unavailable for checkout for price" do |price|
                @book.price = price
                assert_false @book.available_for_checkout?
            end

            use_should("be unavailable for checkout for price").given("zero") { 0 }
            use_should("be unavailable for checkout for price").given("a negative price") { -1 }
        end
    end

And a parameterized shared context.

    context "Book" do
        context "with in-stock book" do
            setup { @book = Book.new(:quantity => 1) }

            share_context "for a book available for checkout at price" do
                # parameters are on the setup and shoulds, not on the context
                setup { |price| @book.price = price }
                
                # we could also access price in the should blocks, but we don't need it again
                should "be in stock" { assert @book.quantity > 0 }
                should "have a non-negative price" { assert @book.price > 0 }
                should "be rentable or purchasable" { assert @book.rentable || @book.purchasable }
            end

            use_context("for a book available for checkout at price").given("a positive price") { 10_00 }
        end
    end

The shared functions also accept multiple parameters when the parameterization block returns an array.

    context "Book" do
        context "with rentable book" do
            setup { @book = Book.new(:rentable => true) }
    
            share_should "be unavailable for checkout for quantity and price" do |quantity, price|
                @book.quantity = quantity
                @book.price = price
                assert_false @book.available_for_checkout?
            end

            use_should("be unavailable for checkout for quantity and price").given("a zero quantity") { [0, 10_00] }
            use_should("be unavailable for checkout for quantity and price").given("a zero price") { [1, 0] }
        end
    end

### Creating a Library of Shared Functionality

The shared functions can also be re-usable across multiple test cases.

In your test helper file:

    class Test::Unit::TestCase
        share_setup "for an in-stock book" do |rentable, purchasable|
            @book = Book.new(:quantity => 1, :price => 10_00, :rentable => rentable, :purchasable => purchasable)
        end
    end

In your test file:

    class BookTest < Test::Unit::TestCase
        context "with an in-stock book" do
            use_setup("for an in-stock book").given { [true, true] }
            
            should "be in stock" { assert @book.quantity > 0 }
        end
    end


# Credits

Shared Shoulda is maintained by [Michael Pearce](http://github.com/michaelgpearce) and is funded by [BookRenter.com](http://www.bookrenter.com "BookRenter.com"). Many of the ideas that have inspired Shared Should come
from practical usage by the Bookrenter software development team and conversations with Bookrenter developers [Andrew Wheeler](http://github.com/jawheeler), [Ben Somers](http://github.com/bensomers), and [Philippe Huibonhoa](http://github.com/phuibonhoa).

![BookRenter.com Logo](http://assets0.bookrenter.com/images/header/bookrenter_logo.gif "BookRenter.com")


# Copyright

Copyright (c) 2011 Michael Pearce, Bookrenter.com. See LICENSE.txt for further details.

