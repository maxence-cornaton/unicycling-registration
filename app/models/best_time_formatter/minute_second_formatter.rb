class BestTimeFormatter::MinuteSecondFormatter
  def self.hint
    "(m)m:ss.xx"
  end

  def self.error_message
    "must have minutes and seconds separated by ':', optionally followed by hundreds (xx)"
  end

  def self.valid?(string)
    numbers = string.split(":")
    return false unless numbers.count == 2

    string[0] = '' if numbers.first.start_with?("0") && numbers.first.length > 1
    string = add_hundreds(string) unless string.index(".")
    to_string(from_string(string)) == string
  end

  # Convert from a string "10:59" to hundreds (65900)
  def self.from_string(string)
    minutes, sec_hund = string.split(":")
    seconds, hundreds = sec_hund.split(".")
    hundreds = hundreds.to_i * 10 if hundreds&.length == 1
    (((minutes.to_i * 60) + seconds.to_i) * 100) + hundreds.to_i
  end

  # Convert from hundreds (65900) to a string "10:59"
  def self.to_string(int)
    return "" if int.nil?

    seconds = int / 100
    hundreds = int % 100

    minutes = seconds / 60
    seconds = seconds % 60
    format("%d:%02d.%02d", minutes, seconds, hundreds)
  end

  def self.add_hundreds(string)
    "#{string}.00"
  end
  private_class_method :add_hundreds
end
