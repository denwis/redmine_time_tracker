module TimeTrackersHelper
  
  def round_hours(hours)
    case hours
           when 0..0.03; hours = 0
           when 0.04..0.25; hours = 0.25
           when 0.26..0.5; hours = 0.5
           else hours = hours.round(1)
    end
    return hours
  end
  
end
