class CandyCrusher::Grid
  Item = CandyCrusher::Item

  def self.match_images(image, x_offset, y_offset, item_image)
    num_pixels = 0
    diff_score = 0

    for y in 0...item_image.height do
      for x in 0...item_image.width do
        begin
        image_px = image[x_offset + x, y_offset + y]
        item_px = item_image[x, y]

        if ChunkyPNG::Color.a(item_px) == ChunkyPNG::Color::MAX
          num_pixels += 1
          diff_score += (ChunkyPNG::Color.r(item_px) - ChunkyPNG::Color.r(image_px)).abs
          diff_score += (ChunkyPNG::Color.g(item_px) - ChunkyPNG::Color.g(image_px)).abs
          diff_score += (ChunkyPNG::Color.b(item_px) - ChunkyPNG::Color.b(image_px)).abs
        end

        rescue
          return 2**30
        end
      end
    end

    diff_score.to_f / num_pixels
  end

  def self.get_grid(image, options={})
    max_i = options[:layouts].map { |l| l[2]+1 }.max
    max_j = options[:layouts].map { |l| l[3]+1 }.max

    grid = new(max_i, max_j, options[:connectors], options[:fall_through])

    for i in 0...max_i do
      for j in 0...max_j do
        best_score = 2**32
        best_item = nil

        unless options[:layouts].any? { |l| l[0] <= i && i <= l[2] &&
                                            l[1] <= j && j <= l[3] }
          next
        end

        Item::MAPPING.each do |item_image, item|
          score = match_images(image, options[:grid][0] + i * Item.width,
                                      options[:grid][1] + j * Item.height, item_image)
          if score < best_score
           best_score = score
           best_item = item
          end
        end

        if best_score > 150
          best_item = nil
        end

        grid[i,j] = best_item
      end
    end

    (options[:set] || []).each do |_i, _j, other_i, other_j, what|
      unless what == 'avoid'
        item = if Item.respond_to?(what)
                 Item.send(what)
               elsif Item.respond_to?("image_#{what}")
                 Item::MAPPING[Item.send("image_#{what}")]
               else
                 raise "Undefined item: #{what}"
               end
      end

      for i in _i...(other_i+1) do
        for j in _j...(other_j+1) do
          if what == 'avoid'
            grid[i,j] = grid[i,j].dup.tap { |_item| _item.modifiers << :avoid }
          else
            grid[i,j] = item
          end
        end
      end
    end

    grid
  end

  attr_accessor :max_i, :max_j, :connectors, :items, :transposed, :fall_through
  def initialize(max_i, max_j, connectors, fall_through)
    @max_i = max_i
    @max_j = max_j
    @items = max_i.times.map { max_j.times.map { Item.nothing } }
    @transposed = false
    @fall_through = fall_through

    @connectors = {}
    connectors.to_a.map do |i,j,k,l, _i,_j|
      for index in (i..k) do
        @connectors[[_i + (index-i), _j]] = [index,j]
      end
    end
  end

  def dup
    super.tap do |grid|
      grid.items = grid.items.map { |l| l.dup }
    end
  end

  def transposed_access
    dup.tap do |grid|
      grid.items = self.items
      grid.transposed = true
    end
  end

  def max_i
    @transposed ? @max_j : @max_i
  end

  def max_j
    @transposed ? @max_i : @max_j
  end

  def [](i,j)
    i,j = j,i if @transposed
    if i < 0 || j < 0 || @items[i].nil? || @items[i][j].nil?
      return Item.nothing
    end
    @items[i][j]
  end

  def []=(i,j, value)
    i,j = j,i if @transposed
    @items[i][j] = value
  end

  def to_s(options={})
    highlight = options[:highlight] || []
    text = [*options[:text]]

    start_text_j = (max_j - text.size)/2

    s = ""
    for j in 0...max_j do
      for i in 0...max_i do
        color = case self[i,j].name
                when 'r' then 31
                when 'y' then 33
                when 'g' then 32
                when 'p' then 35
                when 'b' then 34
                when 'o' then 33
                else 38
                end

        if highlight.include? [i,j]
          s << "\e[3;#{color}m"
        else
          s << "\e[#{self[i,j].special? ? 1 : 0};#{color}m"
        end
        s << "#{self[i,j]}\e[0m "
      end

      s << "   " + text[j - start_text_j] if start_text_j <= j && j < start_text_j + text.size
      s << "\n"
    end
    s
  end

  def inspect
    to_s
  end

  def swap(i,j,other_i,other_j)
    dup.tap do |grid|
      grid[i,j], grid[other_i,other_j] = grid[other_i,other_j], grid[i,j]
      taint = i == other_i ? :vswap : :hswap

      grid[i,j] = grid[i,j].dup.tap { |item| item.taint = taint }
      grid[other_i,other_j] = grid[other_i,other_j].dup.tap { |item| item.taint = taint }
    end
  end

  def remove_taint
    dup.tap do |grid|
      for j in 0...max_j do
        for i in 0...max_i do
          next unless grid[i,j].tainted?
          grid[i,j] = grid[i,j].dup.tap { |item| item.taint = nil }
        end
      end
    end
  end

  def empty_ratio
    num_items = 0
    num_holes = 0

    for j in 0...max_j do
      for i in 0...max_i do
        num_items += 1
        num_holes += 1 if self[i,j] == Item.hole
      end
    end

    1.0 - num_holes.to_f / num_items.to_f
  end

  def above_with_gravity(i,j)
    coords = connectors[[i,j]] || [i,j-1]
    if @fall_through
      while self[*coords] == Item.nothing && coords[1] > 0
        coords = [coords[0], coords[1]-1]
      end
    end
    coords
  end

  def each(&block)
    for i in 0...max_i do
      for j in 0...max_j do
        block.call(i,j)
      end
    end
  end
end
