class CandyCrusher::Logic
  Item = CandyCrusher::Item

  SCORES = {
    :move         => -5,
    :normal       => 1,
    :merge_stripe => 1,
    :stripe       => 10, # Random stripe, not great.
    :vstripe      => 30,
    :hstripe      => 30,
    :sprinkle     => 500,
  }

  def initialize
  end

  def compute_best_move(grid, options={})
    moves = compute_moves(grid, nil, 0)
    all_moves = moves.dup

    options[:max_depth].times.each do |depth|
      next if depth == 0
      puts "Iteration #{depth}"

      new_moves = []

      moves.each do |move|
        move[:next_moves] = compute_moves(move[:new_grid], move, depth)
        new_moves += move[:next_moves]

        break if Time.now > options[:end_time]
      end

      break if new_moves.empty?
      moves = new_moves.sort_by { |m| -m[:score] }
      all_moves += moves
      break if Time.now > options[:end_time]
    end

    all_moves = all_moves.sort_by { |m| -m[:total_score] }

    chain = []
    move = all_moves.first
    until move.nil?
      chain << move
      move = move[:parent]
    end
    chain.reverse
  end

  def compute_moves(grid, parent_move, depth)
    moves = []

    for i in 0...(grid.max_i-1) do
      for j in (0...(grid.max_j-1)).to_a.reverse do
        next unless grid[i,j].movable?

        [[i+1,j], [i,j+1]].each do |swap|
          next unless grid[*swap].movable?
          new_grid, combos, score = apply_game_rules(grid.remove_taint.swap(i,j,*swap))
          next if combos.empty?

          total_score = score
          total_score += parent_move[:total_score] if parent_move
          total_score += SCORES[:move] * depth

          moves << {:swap        => [i,j,*swap],
                    :combos      => combos,
                    :score       => score,
                    :total_score => total_score,
                    :old_grid    => grid,
                    :new_grid    => new_grid,
                    :parent      => parent_move,
                    :next_moves  => nil}
        end
      end
    end

    moves
  end

  def mark_for_destroy(grid, i, j)
    item = grid[i,j]
    return if item.marked_for_destroy?
    return if item == Item.nothing

    grid[i,j] = item.dup.tap { |_item| _item.marked_for_destroy = true }

    # Striped
    methods = [:hstripped?, :vstripped?]
    methods.reverse! if grid.transposed

    if item.send(methods[0])
      for i_ in 0...grid.max_i do
        mark_for_destroy(grid, i_, j)
      end
    end

    if item.send(methods[1])
      for j_ in 0...grid.max_j do
        mark_for_destroy(grid, i, j_)
      end
    end

    # Wrapped
    if item.wrapped?
      mark_for_destroy(grid, i-1,j-1)
      mark_for_destroy(grid, i-1,j)
      mark_for_destroy(grid, i-1,j+1)

      mark_for_destroy(grid, i,j-1)
      mark_for_destroy(grid, i,j)
      mark_for_destroy(grid, i,j+1)

      mark_for_destroy(grid, i+1,j-1)
      mark_for_destroy(grid, i+1,j)
      mark_for_destroy(grid, i+1,j+1)
    end
  end

  def _apply_game_rules(grid, i, j)
    return unless grid[i,j].candy?
    return if [grid[i,j], grid[i+1,j], grid[i+2,j]].any?(&:marked_for_destroy?)

    # Merge stripe
    if grid[i,j].stripped? && grid[i,j].tainted? &&
       grid[i+1,j].stripped? && grid[i+1,j].tainted?
      # XXX Swaping in the other direction is *not* the same
      grid[i,j] = Item.new("x", :candy, :vstripe)
      mark_for_destroy(grid,i,j)
      grid[i,j] = Item.new("x", :candy, :hstripe)
      mark_for_destroy(grid,i,j)
      return :merge_stripe
    end

    # Sprinkle
    if grid[i,j] == grid[i+1,j] &&
       grid[i,j] == grid[i+2,j] &&
       grid[i,j] == grid[i+3,j] &&
       grid[i,j] == grid[i+4,j]
      mark_for_destroy(grid, i,   j)
      mark_for_destroy(grid, i+1, j)
      mark_for_destroy(grid, i+2, j)
      mark_for_destroy(grid, i+3, j)
      mark_for_destroy(grid, i+4, j)

      grid[i+2,j] = Item.sprinkle

      return :sprinkle
    end

    # Stripe
    if grid[i,j] == grid[i+1,j] &&
       grid[i,j] == grid[i+2,j] &&
       grid[i,j] == grid[i+3,j]
      mark_for_destroy(grid, i,   j)
      mark_for_destroy(grid, i+1, j)
      mark_for_destroy(grid, i+2, j)
      mark_for_destroy(grid, i+3, j)

      taint_c = [[i,j], [i+1,j], [i+2,j], [i+3,j]]
                  .select { |c| grid[*c].tainted? }
                  .compact.first
      taint_c = [i,j] unless taint_c

      tainted_item = grid[*taint_c]
      stripe = case tainted_item.taint
               when :hswap then :hstripe
               when :vswap then :vstripe
               else :stripe
               end
      grid[*taint_c] = tainted_item.dup.tap do |item|
        item.marked_for_destroy = false
        # Random stripe, picking hstripe
        item_stripe = stripe == :stripe ? :hstripe : stripe
        item.modifiers << item_stripe
      end
      return stripe
    end

    # Normal
    if grid[i,j] == grid[i+1,j] &&
       grid[i,j] == grid[i+2,j]
      mark_for_destroy(grid, i,   j)
      mark_for_destroy(grid, i+1, j)
      mark_for_destroy(grid, i+2, j)
      return :normal
    end
  end

  def apply_game_rules(grid)
    combos = []
    grid = grid.dup
    empty_ratio = grid.empty_ratio

    [grid, grid.transposed_access].each do |_grid|
      for i in 0..._grid.max_i do
        for j in 0..._grid.max_j do
          c = _apply_game_rules(_grid, i,j)
          combos << c unless c.nil?
        end
      end
    end

    score = combos.map { |c| SCORES[c] }.reduce(:+).to_f

    unless combos.empty?
      grid, new_score = apply_destroys(grid)
      score += new_score

      grid = apply_gravity(grid)

      grid, new_combos, new_score = apply_game_rules(grid)
      combos += new_combos
      score += new_score
    end

    [grid, combos, score * empty_ratio]
  end

  def apply_destroys(grid)
    score = 0
    grid = grid.dup
    for i in 0...(grid.max_i) do
      for j in (0...grid.max_j) do
        next unless grid[i,j].marked_for_destroy?
        next if grid[i,j] == Item.nothing

        if grid[i,j] == Item.chocolate
          score += 300
        end

        if grid[i,j].avoid?
          score -= 10000
        end

        if grid[i,j].locked?
          score += 20
        end

        if grid[i,j].locked?
          grid[i,j] = grid[i,j].dup.tap { |item| item.modifiers - [:locked] }
        else
          grid[i,j] = Item.hole
        end
        score += 1
      end
    end
    [grid, score]
  end

  def _apply_gravity(grid)
    grid = grid.dup

    for i in 0...(grid.max_i) do
      for j in (1...grid.max_j).to_a.reverse do
        if grid[i,j].hole?
          tmp_i, tmp_j = i, j

          loop do
            tmp_i, tmp_j = grid.above_with_gravity(tmp_i, tmp_j)
            if grid[tmp_i, tmp_j].movable?
              grid[i,j] = grid[tmp_i, tmp_j]
              grid[tmp_i, tmp_j] = Item.hole
              break
            end
            break unless grid[tmp_i, tmp_j].hole?
          end

        end
      end
    end

    grid
  end

  def apply_gravity(grid)
    # connectors
    _apply_gravity(_apply_gravity(grid))
  end
end
