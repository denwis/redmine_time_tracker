module TimeTrackerPlugin
  module Patches
    module UserPatch
      extend ActiveSupport::Concern

      included do
        unloadable
      end

      def time_tracker
        TimeTracker.find(:first, :conditions => { :user_id => self.id })
      end

    end
  end
end
