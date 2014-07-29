class ChunkyPNG::Image
  def self.from_file_retina(path)
    image = from_file(path)
    new_image = new(image.width/2, image.height/2)
    for y in 0...new_image.height do
      for x in 0...new_image.width do
        new_image[x,y] = image[x*2,y*2]
      end
    end
    new_image
  end
end
