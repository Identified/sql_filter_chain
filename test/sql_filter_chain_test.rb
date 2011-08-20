require 'test_helper'
require 'active_record'
require 'shoulda'
require '../lib/sql_filter_chain'
require 'pp'

ActiveRecord::Base.establish_connection({
                                          :adapter => 'postgresql',
                                          :database => 'spark_test',
                                          :username => 'spark',
                                          :password => 'spark'
                                        })

ActiveRecord::Schema.define do
  create_table "my_models", :force => true do |t|
    t.column "name",  :text
    t.column "email", :text
  end
end

class SqlFilterChainTest < ActiveSupport::TestCase
  class MyModel < ActiveRecord::Base
    named_scope :bobs, :conditions => "name = 'Bob'"
    named_scope :edu_emails, :conditions => "email ~* '.edu'"
    named_scope :berkeley, :conditions => "email ~* 'berkeley'"
  end
  
  context "#sql_filter_chain with just one scope" do
    setup do
      MyModel.delete_all
      @matching_models = MyModel.sql_filter_chain MyModel.bobs
    end

    should "return equivalent to just the named scope itself" do
      assert_equal MyModel.bobs, @matching_models
    end
  end

  context "" do
    setup do
      MyModel.delete_all
      @bob = MyModel.create :name => "Bob", :email => "bob@berkeley.edu"
      @david = MyModel.create :name => "Dave", :email => "david@berkeley.edu"
      @workingbob = MyModel.create :name => "Bob", :email => "bob@identified.com"
    end

    context "#sql_filter_chain with multiple scopes" do
      setup do
        @matching_models = MyModel.sql_filter_chain MyModel.bobs, MyModel.edu_emails, MyModel.berkeley
      end
      
      should "return only elements that match all scopes" do
        assert_equal [@bob], @matching_models
      end
    end

    context "#sql_filter_chain with multiple scopes and asking for count" do
      setup do
        @count = MyModel.sql_filter_chain(MyModel.bobs, MyModel.edu_emails, MyModel.berkeley).count
      end

      should "return count of elements matching all scopes" do
        assert_equal 1, @count
      end
    end
  end

  context "#sql_filter_chain with multiple scopes and a join table" do
    setup do
      class MyModel < ActiveRecord::Base
        has_one :my_score
        named_scope :score_greater_than, lambda { |score| {:conditions => ["my_scores.score > ?", score], :joins => :my_score} }
      end

      class MyScore < ActiveRecord::Base
        belongs_to :my_model
      end

      ActiveRecord::Schema.define do
        create_table "my_scores", :force => true do |t|
          t.column "my_model_id", :integer
          t.column "score", :integer
        end
      end

      MyModel.delete_all
      MyScore.delete_all

      @lowbob = MyModel.create :name => "Bob", :email => "bob1@berkeley.edu"
      @highbob = MyModel.create :name => "Bob", :email => "bob1@berkeley.edu"

      MyScore.create :my_model => @lowbob, :score => 0.0
      MyScore.create :my_model => @highbob, :score => 10.0

      @matching_models = MyModel.sql_filter_chain MyModel.bobs, MyModel.edu_emails, MyModel.score_greater_than(1.0)
    end

    should "return only elements that match all scopes" do
      assert_equal [@highbob], @matching_models
    end
  end
end
