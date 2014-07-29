require 'tempfile'

class CandyCrusher::ScreenCapture
  attr_accessor :x, :y, :w, :h
  def initialize(x,y,w,h)
    @x = x
    @y = y
    @w = w
    @h = h
  end

  def capture_file(&block)
    path = "/tmp/candy-crusher-#{rand(2**30)}"
    `screencapture -R#{@x},#{@y},#{@w},#{@h} #{path}`
    if block
      begin
        block.call(path)
      ensure
        File.unlink(path)
      end
    else
      path
    end
  end

  def capture
    capture_file do |path|
      ChunkyPNG::Image.from_file_retina(path)
    end
  end
end
