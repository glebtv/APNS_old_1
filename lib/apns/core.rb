class OverSized < Exception
end

require 'timeout'

module APNS
  require 'socket'
  require 'openssl'
  require 'yajl'

  @host = 'gateway.sandbox.push.apple.com'
  @port = 2195
  # openssl pkcs12 -in mycert.p12 -out client-cert.pem -nodes -clcerts
  @pem = nil # this should be the path of the pem file not the contentes
  @pass = nil
  
  class << self
    attr_accessor :host, :pem, :port, :pass
  end
  
  def self.send_notification(device_token, message)
    n = APNS::Notification.new(device_token, message)
    self.send_notifications([n])
  end
  
  def self.send_notifications(notifications)
    sock, ssl = self.open_connection
    
    id = 100
    notifications.each do |n|
      pck = n.packaged_notification(id)
      pck.hexdump
      raise OverSized if pck.size.to_i > 256
      ssl.syswrite(pck)
      id += 1
      begin
        Timeout::timeout(1) do
          while line = ssl.read(6)
            # line.hexdump
            # p line.unpack("CCN")
          end
        end
      rescue Exception => e
        # p e
      end
    end
    
    ssl.close
    sock.close
  end
  
  def self.feedback
    sock, ssl = self.feedback_connection
    
    apns_feedback = []
    buffer = ''
    begin
      while line = ssl.sysread(38) # Read lines from the socket
        buffer += line
      end
    rescue EOFError => e
      
    end
    index = 0
    loop do
      rtime = buffer[index..index+3].unpack('N1')
      time = Time.at(rtime[0])
      length = buffer[index+4..index+5].unpack('n1')[0]
      token = buffer[index+6..index+6+length].unpack("H#{length}")[0]
      apns_feedback << [time, token]
      
      index += length+6
      break if index > buffer.length
    end unless buffer.empty?
    
    ssl.close
    sock.close
    
    return apns_feedback
  end
  
  protected

  def self.open_connection
    raise "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless self.pem
    raise "The path to your pem file does not exist!" unless File.exist?(self.pem)
    
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(self.pem))
    context.key  = OpenSSL::PKey::RSA.new(File.read(self.pem), self.pass)

    context.ca_file = '/data/ps/cert/server-ca-cert.pem'
    context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    
    sock         = TCPSocket.new(self.host, self.port)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock,context)
    ssl.sync = true
    ssl.connect

    return sock, ssl
  end
  
  def self.feedback_connection
    raise "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless self.pem
    raise "The path to your pem file does not exist!" unless File.exist?(self.pem)
    
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(self.pem))
    context.key  = OpenSSL::PKey::RSA.new(File.read(self.pem), self.pass)
    
    context.ca_file = '/data/ps/cert/server-ca-cert.pem'
    context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    
    fhost = self.host.gsub('gateway','feedback')
    puts fhost
    
    sock         = TCPSocket.new(fhost, 2196)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock,context)
    ssl.sync = true
    ssl.connect

    return sock, ssl
  end
  
end
