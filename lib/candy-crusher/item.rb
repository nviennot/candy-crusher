require 'set'

class CandyCrusher::Item
  attr_accessor :name, :modifiers, :taint, :marked_for_destroy
  def initialize(name, *modifiers)
    @name = name
    @modifiers = Set.new(modifiers)
  end

  class << self
    Dir['assets/*.png'].each do |asset|
      image = ChunkyPNG::Image.from_file_retina(asset)
      asset =~ /\/([^\/]+).png/
      define_method("image_#{$1}") { image }
    end

    def width;  @width  ||= image_red.width;  end
    def height; @height ||= image_red.height; end

    def hole
      @hole ||= new(".")
    end

    def jelly
      @jelly ||= new(".", :jelly)
    end

    def nothing
      @nothing ||= new(" ")
    end

    def sprinkle
      @spinkle ||= new("S", :candy)
    end

    def chocolate
      @chocolate ||= new("X")
    end

    def chantilly
      @chantilly ||= new("O")
    end
  end

  MAPPING = {
    image_red       => new("r", :candy),
    image_blue      => new("b", :candy),
    image_orange    => new("o", :candy),
    image_purple    => new("p", :candy),
    image_yellow    => new("y", :candy),
    image_green     => new("g", :candy),

    image_locked_red       => new("r", :candy, :locked),
    image_locked_blue      => new("b", :candy, :locked),
    image_locked_orange    => new("o", :candy, :locked),
    image_locked_purple    => new("p", :candy, :locked),
    image_locked_yellow    => new("y", :candy, :locked),
    image_locked_green     => new("g", :candy, :locked),

    image_vstripe_red       => new("r", :candy, :vstripe),
    image_vstripe_blue      => new("b", :candy, :vstripe),
    image_vstripe_orange    => new("o", :candy, :vstripe),
    image_vstripe_purple    => new("p", :candy, :vstripe),
    image_vstripe_yellow    => new("y", :candy, :vstripe),
    image_vstripe_green     => new("g", :candy, :vstripe),

    image_hstripe_red       => new("r", :candy, :hstripe),
    image_hstripe_blue      => new("b", :candy, :hstripe),
    image_hstripe_orange    => new("o", :candy, :hstripe),
    image_hstripe_purple    => new("p", :candy, :hstripe),
    image_hstripe_yellow    => new("y", :candy, :hstripe),
    image_hstripe_green     => new("g", :candy, :hstripe),

    image_wrapped_red       => new("r", :candy, :wrapped),
    image_wrapped_blue      => new("b", :candy, :wrapped),
    image_wrapped_orange    => new("o", :candy, :wrapped),
    image_wrapped_purple    => new("p", :candy, :wrapped),
    image_wrapped_yellow    => new("y", :candy, :wrapped),
    image_wrapped_green     => new("g", :candy, :wrapped),

    image_sprinkle  => sprinkle,
    image_chocolate => chocolate,

    image_empty_double_jelly => jelly,
    image_chantilly => chantilly,

    image_nut    => new("N", :fruit),
    image_cherry => new("C", :fruit),
  }

  def dup
    super.tap { |item| item.modifiers = item.modifiers.dup }
  end

  def candy?
    modifiers.include? :candy
  end

  def fruit?
    modifiers.include? :fruit
  end

  def proximity_breakable?
    self == self.class.chocolate || self == self.class.chantilly
  end

  def avoid?
    modifiers.include? :avoid
  end

  def locked?
    modifiers.include? :locked
  end

  def special?
    stripped? || wrapped? || fruit? || self == self.class.sprinkle
  end

  def movable?
    (candy? || fruit?) && !locked?
  end

  def wrapped?
    modifiers.include? :wrapped
  end

  def hstripped?
    modifiers.include? :hstripe
  end

  def vstripped?
    modifiers.include? :vstripe
  end

  def stripped?
    !(modifiers & [:vstripe, :hstripe]).empty?
  end

  def tainted?
    !!taint
  end

  def marked_for_destroy?
    !!@marked_for_destroy
  end

  def hole?
    self == self.class.hole
  end

  def to_s
    name
  end

  def inspect
    to_s
  end

  def ==(other)
    return super unless self.class == other.class
    name == other.name
  end
  alias_method :eql?, :==

  def hash
    name.hash
  end
end
