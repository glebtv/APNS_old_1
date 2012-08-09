module APNS
  class Notification
    attr_accessor :device_token, :alert, :badge, :sound, :other
    
    def initialize(device_token, message)
      self.device_token = device_token
      if message.is_a?(Hash)
        self.alert = message[:alert]
        self.badge = message[:badge]
        self.sound = message[:sound]
        self.other = message[:other]
      elsif message.is_a?(String)
        self.alert = message
      else
        raise "Notification needs to have either a hash or string"
      end
    end
        
    def packaged_notification(id)
      pt = self.packaged_token
      pm = self.packaged_message
      msg = [1, id, 0, pt.bytesize, pt, pm.bytesize, pm]
      msg = msg.pack("C1N1N1na*na*")
      msg
    end
  
    def packaged_token
      [device_token.gsub(/[\s|<|>]/,'')].pack('H*')
    end
  
    def packaged_message
      aps = {'aps'=> {} }
      aps['aps']['alert'] = self.alert if self.alert
      aps['aps']['badge'] = self.badge if self.badge
      aps['aps']['sound'] = self.sound if self.sound
      aps.merge!(self.other) if self.other
      Yajl::Encoder.new.encode(aps)
    end
    
  end
end
