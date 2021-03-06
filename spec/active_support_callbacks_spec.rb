# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'Callbacks' do
  describe 'Default' do
    let(:workflow_class) do
      new_workflow_class(ActiveRecord::Base) do
        event_args :lock, :save, :halted, :raise_after_transition
        state :new do
          on :accept, to: :accepted, meta: { validates_presence_of: [:title, :body] }
          on :reject, to: :rejected
        end
        state :accepted do
          on :blame, to: :blamed, meta: { validates_presence_of: [:title, :body, :blame_reason] }
          on :delete, to: :deleted
        end
        state :rejected do
          on :delete, to: :deleted
        end
        state :blamed do
          on :delete, to: :deleted
        end
        state :deleted do
          on :accept, to: :accepted
        end
      end
    end

    before do
      unless Object.const_defined?(:ActiveSupportArticle)
        Object.const_set(:ActiveSupportArticle, workflow_class)
        workflow_class.class_eval do
          def wrap_in_transaction?
            transition_context.lock
          end

          def in_transition_validations
            from, to, triggering_event, event_args = transition_context.values

            singleton = class << self; self end
            validations = proc {}

            meta = ActiveSupportArticle.workflow_spec.find_state(from).find_event(triggering_event).meta
            fields_to_validate = meta[:validates_presence_of]
            if fields_to_validate
              validations = proc do
                #  Don't use deprecated behavior in ActiveRecord 5.
                if ActiveRecord::VERSION::MAJOR == 5
                  fields_to_validate.each do |field|
                    errors.add(field, :empty) if self[field].blank?
                  end
                else
                  errors.add_on_blank(fields_to_validate) if fields_to_validate
                end
              end
            end

            singleton.send :define_method, :validate_for_transition, &validations
            validate_for_transition
            halt! "Event[#{triggering_event}]'s transitions_to[#{to}] is not valid." unless errors.empty?
            save! if transition_context.save
          end

          def wrap_in_transaction(&block)
            with_lock(&block)
          end

          def check_for_halt_message
            if transition_context.halted
              raise 'This is a problem'
            else
              yield
            end
          end

          def set_attributes_from_event_args
            self.attributes = transition_context.attributes
          end

          def raise_error_if_flagged
            raise 'There was an error' if transition_context.raise_after_transition
          end

          # around_transition :wrap_in_transaction, if: :wrap_in_transaction?
          around_transition if: :wrap_in_transaction? do |article, transition|
            article.with_lock do
              transition.call
            end
          end

          around_transition :check_for_halt_message
          before_transition :set_attributes_from_event_args, :in_transition_validations
          after_transition :raise_error_if_flagged

          before_transition only: :delete do |article|
            article.message = 'Ran transition'
          end

          attr_accessor :message
        end
      end
    end

    before do
      ActiveRecord::Schema.define do
        create_table :active_support_articles do |t|
          t.string :title
          t.string :body
          t.string :blame_reason
          t.string :reject_reason
          t.string :workflow_state
        end
      end

      exec "INSERT INTO active_support_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('new1', NULL, NULL, NULL, 'new')"
      exec "INSERT INTO active_support_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('new2', 'some content', NULL, NULL, 'new')"
      exec "INSERT INTO active_support_articles(title, body, blame_reason, reject_reason, workflow_state) VALUES('accepted1', 'some content', NULL, NULL, 'accepted')"
    end

    it 'should deny transition from new to accepted because of the missing presence of the body' do
      a = ActiveSupportArticle.find_by_title('new1')
      expect { a.accept! }.to raise_error(Workflow::TransitionHaltedError)
      expect(a).to have_persisted_state(:new)
    end

    it 'should allow transition from new to accepted because body is present this time' do
      a = ActiveSupportArticle.find_by_title('new2')
      expect(a.accept!).to be_truthy
      expect(a).to have_persisted_state(:accepted)
    end

    it 'should allow transition from accepted to blamed because of a blame_reason' do
      a = ActiveSupportArticle.find_by_title('accepted1')
      a.blame_reason = 'Provocant thesis'
      expect { a.blame! }.to change {
        ActiveSupportArticle.find_by_title('accepted1').workflow_state
      }.from('accepted').to('blamed')
    end

    it 'should deny transition from accepted to blamed because of no blame_reason' do
      a = ActiveSupportArticle.find_by_title('accepted1')
      expect do
        expect do
          assert a.blame!
        end.to raise_error(Workflow::TransitionHaltedError)
      end.not_to change { ActiveSupportArticle.find_by_title('accepted1').workflow_state }
    end

    describe 'Around Transition' do
      it 'can halt the execution' do
        a = ActiveSupportArticle.new
        expect do
          a.accept! false, false, true
        end.to raise_error(RuntimeError, 'This is a problem')

        expect(a).to be_new
      end

      describe 'halting callback chain in before transition callbacks' do
        let(:subclass) { Class.new(ActiveSupportArticle) }
        subject { subclass.find_by_title 'new1' }

        describe 'when there is no :abort thrown' do
          it 'should complete the transition' do
            expect do
              subject.reject!
            end.to change {
              subject.class.find(subject.id).workflow_state
            }.from('new').to('rejected')
          end
        end

        describe 'when halt is called' do
          before do
            subclass.prepend_before_transition only: :reject do |_article|
              halt
            end
          end
          it 'should not complete the :reject transition' do
            expect do
              subject.reject!
            end.not_to change {
              subject.class.find(subject.id).workflow_state
            }
          end
          it 'should allow non-matching transitions to continue' do
            expect do
              subject.accept! true, true, body: 'Blah'
            end.to change {
              subject.class.find(subject.id).workflow_state
            }.from('new').to('accepted')
          end
        end
      end

      describe 'locking behavior' do
        subject { ActiveSupportArticle.find_by_title('new1') }

        describe 'When attributes are set but not persisted before the state transition' do
          before do
            subject.body = 'Blah'
          end
          it 'should halt the transition' do
            expect do
              subject.accept! true
            end.to raise_error(Workflow::TransitionHaltedError)
          end
        end

        describe 'When attribute changes are all persisted before the state transition' do
          before do
            subject.update body: 'Blah'
          end
          it 'should complete the state change' do
            expect do
              subject.accept! true
            end.to change {
              subject.class.find(subject.id).workflow_state
            }.from('new').to('accepted')
          end
        end

        describe 'When attribute changes are passed along as a part of the transition' do
          it 'executes the transition' do
            expect do
              subject.accept! true, true, body: 'Blah'
            end.to change {
              subject.class.find(subject.id).workflow_state
            }.from('new').to('accepted')
          end

          it 'updates the body of the article' do
            expect do
              subject.accept! true, true, body: 'Blah'
            end.to change {
              subject.class.find(subject.id).body
            }.from(nil).to('Blah')
          end
        end

        describe 'when a downstream error occurs after changes were persisted' do
          it 'rolls back the changes to the workflow state' do
            expect do
              expect do
                subject.accept! true, true, false, true, body: 'Blah'
              end.to raise_error(RuntimeError, 'There was an error')
            end.not_to change {
              subject.class.find(subject.id).workflow_state
            }
          end

          it 'rolls back the changes to the attributes' do
            expect do
              expect do
                subject.accept! true, true, false, true, body: 'Blah'
              end.to raise_error(RuntimeError, 'There was an error')
            end.not_to change {
              subject.class.find(subject.id).body
            }
          end
        end
      end
    end
  end

  describe 'named arguments' do
    let(:workflow_class) do
      new_workflow_class do
        state :new do
          on :go, to: :done
        end
        state :done
      end
    end
    subject do
      workflow_class.new
    end

    before do
      workflow_class.class_eval do
        attr_accessor :message
      end
    end

    it 'Collects the arguments correctly' do
      workflow_class.class_eval do
        before_transition do |obj, a, b, *c|
          obj.message = { a: a, b: b, c: c }
        end
      end
      subject.go! :what, :cool, :dope, :sauce, :whatever
      expect(subject.message).to eq(a: :what, b: :cool, c: [:dope, :sauce, :whatever])
    end

    it 'Collects the arguments correctly, including (from, to, and event)' do
      workflow_class.class_eval do
        before_transition do |obj, a, b, from, to, event, *c|
          obj.message = { a: a, b: b, c: c, from: from, to: to, event: event }
        end
      end
      subject.go! :what, :cool, :dope, :sauce, :whatever
      expect(subject.message).to eq(a: :what, b: :cool, c: [:dope, :sauce, :whatever],
                                    from: :new, to: :done, event: :go)
    end
  end

  describe 'keyword arguments' do
    let(:workflow_class) do
      new_workflow_class do
        event_args :dope, :sauce
        state :new do
          on :go, to: :done
        end
        state :done
      end
    end

    subject do
      workflow_class.new
    end

    before do
      workflow_class.class_eval do
        attr_accessor :message
      end
    end
    it 'should receive the correct argument' do
      workflow_class.class_eval do
        block = proc do |target|
          inner = proc do |message:|
            self.message = message
          end
          target.instance_exec(message: transition_context.attributes[:message], &inner)
        end

        before_transition block
      end
      subject.go! foo: :whatever, message: :you_rule
      expect(subject.message).to eq :you_rule
    end

    it 'Does it 1' do
      workflow_class.class_eval do
        before_transition do |obj, message:|
          obj.message = message
        end
      end
      subject.go! foo: :whatever, message: :you_rule
      expect(subject.message).to eq :you_rule
    end

    it 'Does it 1' do
      workflow_class.class_eval do
        before_transition do |message:|
          self.message = message
        end
      end
      subject.go! foo: :whatever, message: :you_rule
      expect(subject.message).to eq :you_rule
    end

    it 'Does it 2' do
      workflow_class.class_eval do
        before_transition do |_obj, _dope, sauce, message:, **the_rest|
          self.message = [sauce, message, the_rest]
        end
      end
      subject.go! 'tight', 'marmaduke', foo: :whatever, message: :you_rule, tight: :dope
      expect(subject.message).to eq ['marmaduke', :you_rule, { foo: :whatever, tight: :dope }]
    end

    it 'On around transitions' do
      workflow_class.class_eval do
        around_transition do |_obj, callbacks, _dope, sauce, message:, **the_rest|
          self.message = [sauce, message, the_rest]
          callbacks.call
        end
      end
      subject.go! 'tight', 'marmaduke', foo: :whatever, message: :you_rule, tight: :dope
      expect(subject.message).to eq ['marmaduke', :you_rule, { foo: :whatever, tight: :dope }]
      expect(subject).to be_done
    end
  end
end
