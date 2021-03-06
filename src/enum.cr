# Enum is the base type of all enums.
#
# An enum is a set of integer values, where each value has an associated name. For example:
#
# ```
# enum Color
#   Red    # 0
#   Green  # 1
#   Blue   # 2
# end
# ```
#
# Values start with the value 0 and are incremented by one, but can be overwritten.
#
# To get the underlying value you invoke value on it:
#
# ```
# Color::Green.value #=> 1
# ```
#
# Each constant (member) in the enum has the type of the enum:
#
# ```
# typeof(Color::Red) #=> Color
# ```
#
# ### Flags enum
#
# An enum can be marked with the @[Flags] attribute. This changes the default values:
#
# ```
# @[Flags]
# enum IOMode
#   Read   # 1
#   Write  # 2
#   Async  # 4
# end
# ```
#
# Additionally, some methods change their behaviour.
#
# ### Enums from integers
#
# An enum can be created from an integer:
#
# ```
# puts Color.new(1) #=> prints "Green"
# ```
#
# Values that don't correspond to an enum's constants are allowed: the value will still be of type Color,
# but when printed you will get the underlying value:
#
# ```
# puts Color.new(10) #=> prints "10"
# ```
#
# This method is mainly intended to convert integers from C to enums in Crystal.
struct Enum
  include Comparable(self)

  # Appends a String representation of this enum member to the given IO. See `to_s`.
  macro def to_s(io : IO) : Nil
    {% if @enum_flags %}
      if value == 0
        io << "None"
      else
        found = false
        {% for member in @constants %}
          {% if member.stringify != "All" %}
            if {{member}}.value != 0 && (value & {{member}}.value) == {{member}}.value
              io << ", " if found
              io << {{member.stringify}}
              found = true
            end
          {% end %}
        {% end %}
        io << value unless found
      end
    {% else %}
      io << to_s
    {% end %}
    nil
  end

  # Returns a String representation of this enum member.
  # In the case of regular enums, this is just the name of the member.
  # In the case of flag enums, it's the names joined by commas, or "None",
  # if the value is zero.
  #
  # If an enum's value doesn't match a member's value, the raw value
  # is returned as a string.
  #
  # ```
  # Color::Red.to_s   #=> "Red"
  # IOMode::None.to_s #=> "None"
  # (IOMode::Read | IOMode::Write).to_s #=> "Read, Write"
  #
  # Color.new(10).to_s #=> "10"
  # ```
  macro def to_s : String
    {% if @enum_flags %}
      String.build { |io| to_s(io) }
    {% else %}
      case value
      {% for member in @constants %}
      when {{member}}.value
        {{member.stringify}}
      {% end %}
      else
        value.to_s
      end
    {% end %}
  end

  # Returns the value of this enum member as an `Int32`.
  #
  # ```
  # Color::Blue.to_i #=> 2
  # (IOMode::Read | IOMode::Write).to_i #=> 3
  #
  # Color.new(10).to_i #=> 10
  # ```
  def to_i : Int32
    value.to_i32
  end

  # Returns the enum member that results from adding *other*
  # to this enum member's value.
  #
  # ```
  # Color::Red + 1 #=> Color::Blue
  # Color::Red + 2 #=> Color::Green
  # Color::Red + 3 #=> 3
  # ```
  def +(other : Int)
    self.class.new(value + other)
  end

  # Returns the enum member that results from subtracting *other*
  # to this enum member's value.
  #
  # ```
  # Color::Blue - 1 #=> Color::Green
  # Color::Blue - 2 #=> Color::Red
  # Color::Blue - 3 #=> -1
  # ```
  def -(other : Int)
    self.class.new(value - other)
  end

  # Returns the enum member that results from applying a logical
  # "or" operation betwen this enum member's value and *other*.
  # This is mostly useful with flag enums.
  #
  # ```
  # (IOMode::Read | IOMode::Async) #=> IOMode::Read | IOMode::Async
  # ```
  def |(other : self)
    self.class.new(value | other.value)
  end

  # Returns the enum member that results from applying a logical
  # "and" operation betwen this enum member's value and *other*.
  # This is mostly useful with flag enums.
  #
  # ```
  # (IOMode::Read | IOMode::Async) & IOMode::Read #=> IOMode::Read
  # ```
  def &(other : self)
    self.class.new(value & other.value)
  end

  # Returns the enum member that results from applying a logical
  # "xor" operation betwen this enum member's value and *other*.
  # This is mostly useful with flag enums.
  def ^(other : self)
    self.class.new(value ^ other.value)
  end

  # Returns the enum member that results from applying a logical
  # "not" operation of this enum member's value.
  def ~
    self.class.new(~value)
  end

  # Compares this enum member against another, according to their underlying
  # value.
  #
  # ```
  # Color::Red <=> Color::Blue  #=> -1
  # Color::Blue <=> Color::Red  #=> 1
  # Color::Blue <=> Color::Blue #=> 0
  # ```
  def <=>(other : self)
    value <=> other.value
  end

  # Returns `true` if this enum member's value includes *other*. This
  # performs a logical "and" between this enum member's value and *other*'s,
  # so instead of writing:
  #
  # ```
  # (member & value) != 0
  # ```
  #
  # you can write:
  #
  # ```
  # member.includes?(value)
  # ```
  #
  # The above is mostly useful with flag enums.
  #
  # For example:
  #
  # ```
  # mode = IOMode::Read | IOMode::Write
  # mode.includes?(IOMode::Read)  #=> true
  # mode.includes?(IOMode::Async) #=> false
  # ```
  def includes?(other : self)
    (value & other.value) != 0
  end

  # Returns `true` if this enum member and *other* have the same underlying value.
  #
  # ```
  # Color::Red == Color::Red  #=> true
  # Color::Red == Color::Blue #=> false
  # ```
  def ==(other : self)
    value == other.value
  end

  # Returns a hash value. This is the hash of the underlying value.
  def hash
    value.hash
  end

  # Returns all enum members as an `Array(String)`.
  #
  # ```
  # Color.names #=> ["Red", "Green", "Blue"]
  # ```
  macro def self.names : Array(String)
    {% if @enum_flags %}
      {{ @constants.select { |e| e.stringify != "None" && e.stringify != "All" }.map &.stringify }}
    {% else %}
      {{ @constants.map &.stringify }}
    {% end %}
  end

  # Returns all enum members as an `Array(self)`.
  #
  # ```
  # Color.values #=> [Color::Red, Color::Green, Color::Blue]
  # ```
  macro def self.values : Array(self)
    {% if @enum_flags %}
      {{ @constants.select { |e| e.stringify != "None" && e.stringify != "All" } }}
    {% else %}
      {{ @constants }}
    {% end %}
  end

  # Returns the enum member that has the given value, or `nil` if
  # no such member exists.
  #
  # ```
  # Color.from_value?(0) #=> Color::Red
  # Color.from_value?(1) #=> Color::Green
  # Color.from_value?(2) #=> Color::Blue
  # Color.from_value?(3) #=> nil
  # ```
  macro def self.from_value?(value) : self | Nil
    {% for member in @constants %}
      return {{member}} if {{member}}.value == value
    {% end %}
    nil
  end

  # Returns the enum member that has the given value, or raises
  # if no such member exists.
  #
  # ```
  # Color.from_value?(0) #=> Color::Red
  # Color.from_value?(1) #=> Color::Green
  # Color.from_value?(2) #=> Color::Blue
  # Color.from_value?(3) #=> Exception
  # ```
  macro def self.from_value(value) : self
    from_value?(value) || raise "Unknown enum #{self} value: #{value}"
  end

  # macro def self.to_h : Hash(String, self)
  #   {
  #     {% for member in @constants %}
  #       {{member.stringify}} => {{member}},
  #     {% end %}
  #   }
  # end

  # Returns the enum member that has the given name, or
  # raises if no such member exists. The lookup is case-insensitive.
  #
  # ```
  # Color.parse("Red")    #=> Color::Red
  # Color.parse("BLUE")   #=> Color::Blue
  # Color.parse("Yellow") #=> Exception
  # ```
  def self.parse(string)
    parse?(string) || raise "Unknown enum #{self} value: #{string}"
  end

  # Returns the enum member that has the given name, or
  # `nil` if no such member exists. The lookup is case-insensitive.
  #
  # ```
  # Color.parse?("Red")    #=> Color::Red
  # Color.parse?("BLUE")   #=> Color::Blue
  # Color.parse?("Yellow") #=> nil
  # ```
  macro def self.parse?(string) : self ?
    case string.downcase
    {% for member in @constants %}
      when {{member.stringify.downcase}}
        {{member}}
    {% end %}
    else
      nil
    end
  end

  # def self.each
  #   to_h.each do |key, value|
  #     yield key, value
  #   end
  # end
end
