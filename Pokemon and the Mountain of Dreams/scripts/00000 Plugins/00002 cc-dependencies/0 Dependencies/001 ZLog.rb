# Ruby's Kernel module
module Kernel
  # Display a log message for Zøzo plugins.
  # @param message [String]
  # @return [String]
  def z_log(message)
    rc = binding.receiver
    rc = rc.is_a?(Module) ? rc : rc.class
    pcc "[#{rc}] #{message}", 0x05
    return message
  end
end
