module Recognition
  module Extensions
    module ActiveRecord
      def self.included(base)
        base.extend ClassMethods
        base.class_attribute :recognitions
        base.class_attribute :recognizable
      end

      module ClassMethods
        # to be called from user model
        def acts_as_recognizable options = {}
          require "recognition/models/recognizable"
          include Recognition::Models::Recognizable
          self.recognizable = true
          self.recognitions ||= {}
          self.recognitions[:initial] = {
            amount: options[:initial]
          }
          after_create :add_initial_points
        end
  
        # to be called from other models
        def recognize recognizable, condition
          require "recognition/models/recognizer"
          include Recognition::Models::Recognizer
          self.recognitions ||= {}
          self.recognitions[condition[:for]] = {
            recognizable: recognizable,
            bucket: condition[:group],
            gain: condition[:gain],
            loss: condition[:loss],
            maximum: condition[:maximum]
          }
          # Due to the lack of ActiveRecord before_filter,
          # we will have to alias the original method in order to intercept
          if [:create, :update, :destroy].include? condition[:for]
            include ActiveModel::Dirty
          else
            method = condition[:for]
            define_method "#{method}_with_recognition" do |*args|
              if self.send("#{method}_without_recognition", *args)
                Recognition::Database.update_points self, condition[:for], self.class.recognitions[condition[:for]]
              end
            end
            alias_method_chain method, 'recognition'
          end
          # For actions that can be intercepted using ActiveRecord callbacks
          before_destroy :recognize_destroying
          after_save :recognize_updating 
          # We use after_save for creation to make sure all associations
          # have been persisted
          after_save :recognize_creating
        end

        def acts_as_voucher options = {}
          require "recognition/models/voucher"
          include Recognition::Models::Voucher
          self.recognitions = options
          cattr_accessor :redemption_validators
          def self.validates_voucher_redmeption validators
            self.redemption_validators ||= []
            self.redemption_validators << validators
            self.redemption_validators.flatten!
          end
          before_create :regenerate_code
        end

        def acts_as_gift options = {}
          require "recognition/models/gift"
          include Recognition::Models::Gift
          self.recognitions = options
          cattr_accessor :redemption_validators
          def self.validates_gift_redmeption validators
            self.redemption_validators ||= []
            self.redemption_validators << validators
            self.redemption_validators.flatten!
          end
          before_create :regenerate_code
        end
      end
    end
  end
end
