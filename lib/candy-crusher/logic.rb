class CandyCrusher::Logic
  Item = CandyCrusher::Item

  SCORES = {
    :normal   => 1,
    :stripe   => 10, # Random stripe, not great.
    :vstripe  => 100,
    :hstripe  => 100,
    :sprinkle => 10000,
  }

  def initialize
  end

  def compute_best_move(grid, options={})
    moves = compute_moves(grid, nil)
    all_moves = moves.dup

    options[:max_depth].times.each do |depth|
      puts "Iteration #{depth+1}"
      next if depth == 1

      new_moves = []

      moves.each do |move|
        move[:next_moves] = compute_moves(move[:new_grid], move)
        new_moves += move[:next_moves]

        break if Time.now > options[:end_time]
      end

      break if new_moves.empty?
      moves = new_moves.sort_by { |m| m[:score] }
      all_moves += moves
      break if Time.now > options[:end_time]
    end

    all_moves.sort_by { |m| m[:score] }

    chain = []
    move = all_moves.last
    until move.nil?
      chain << move
      move = move[:parent]
    end
    chain.reverse
  end

  def compute_moves(grid, parent_move)
    moves = []

    for i in 0...(grid.max_i-1) do
      for j in (0...(grid.max_j-1)).to_a.reverse do
        next unless grid[i,j].movable?

        [[i+1,j], [i,j+1]].each do |swap|
          next unless grid[*swap].movable?
          new_grid, combos, score = apply_game_rules(grid.remove_taint.swap(i,j,*swap))
          next if combos.empty?

          moves << {:swap       => [i,j,*swap],
                    :combos     => combos,
                    :score      => score,
                    :old_grid   => grid,
                    :new_grid   => new_grid,
                    :parent     => parent_move,
                    :next_moves => nil}
        end
      end
    end

    moves
  end

  def apply_game_rules(grid)
    combos = []
    grid = grid.dup

    empty_ratio = grid.empty_ratio

    for i in 0...(grid.max_i-2) do
      for j in 0...(grid.max_j-2) do
        next unless grid[i,j].candy?

        # HORIZONTAL

        if grid[i,j] == grid[i+1,j] &&
           grid[i,j] == grid[i+2,j] &&
           grid[i,j] == grid[i+3,j] &&
           grid[i,j] == grid[i+4,j]
          grid.destroy!(i,j)
          grid.destroy!(i+1,j)
          grid.destroy!(i+2,j)
          grid.destroy!(i+3,j)
          grid.destroy!(i+4,j)
          combos << :sprinkle
        end

        if grid[i,j] == grid[i+1,j] &&
           grid[i,j] == grid[i+2,j] &&
           grid[i,j] == grid[i+3,j]
          taint_c = [[i,j], [i+1,j], [i+2,j], [i+3,j]]
                      .select { |c| grid[*c].tainted? }
                      .compact.first
          if taint_c
            tainted_item = grid[*taint_c]
            stripe = case tainted_item.taint
                     when :hswap then :hstripe
                     when :vswap then :vstripe
                     end
            grid[*taint_c] = tainted_item.dup.tap { |item| item.modifiers << stripe }
          end

          grid.destroy!(i,j)   unless taint_c == [i,j]
          grid.destroy!(i+1,j) unless taint_c == [i+1,j]
          grid.destroy!(i+2,j) unless taint_c == [i+2,j]
          grid.destroy!(i+3,j) unless taint_c == [i+3,j]

          combos << if    taint_c && grid[*taint_c].hstripped? then :hstripe
                    elsif taint_c && grid[*taint_c].vstripped? then :vstripe
                    else :stripe
                    end
        end

        if grid[i,j] == grid[i+1,j] &&
           grid[i,j] == grid[i+2,j]
          grid.destroy!(i,j)
          grid.destroy!(i+1,j)
          grid.destroy!(i+2,j)
          combos << :normal
        end

        # VERTICAL

        if grid[i,j] == grid[i,j+1] &&
           grid[i,j] == grid[i,j+2] &&
           grid[i,j] == grid[i,j+3] &&
           grid[i,j] == grid[i,j+4]

          grid.destroy!(i,j)
          grid.destroy!(i,j+1)
          grid.destroy!(i,j+2)
          grid.destroy!(i,j+3)
          grid.destroy!(i,j+4)
          combos << :sprinkle
        end

        if grid[i,j] == grid[i,j+1] &&
           grid[i,j] == grid[i,j+2] &&
           grid[i,j] == grid[i,j+3]

          taint_c = [[i,j], [i,j+1], [i,j+2], [i,j+3]]
                      .select { |c| grid[*c].tainted? }
                      .compact.first
          if taint_c
            tainted_item = grid[*taint_c]
            stripe = case tainted_item.taint
                     when :hswap then :hstripe
                     when :vswap then :vstripe
                     end
            grid[*taint_c] = tainted_item.dup.tap { |item| item.modifiers << stripe }
          end

          grid.destroy!(i,j)   unless taint_c == [i,j]
          grid.destroy!(i,j+1) unless taint_c == [i,j+1]
          grid.destroy!(i,j+2) unless taint_c == [i,j+2]
          grid.destroy!(i,j+3) unless taint_c == [i,j+3]

          combos << if    taint_c && grid[*taint_c].hstripped? then :hstripe
                    elsif taint_c && grid[*taint_c].vstripped? then :vstripe
                    else :stripe
                    end
        end

        if grid[i,j] == grid[i,j+1] &&
           grid[i,j] == grid[i,j+2]
          grid.destroy!(i,j)
          grid.destroy!(i,j+1)
          grid.destroy!(i,j+2)
          combos << :normal
        end
      end
    end

    unless combos.empty?
      grid, new_combos, score = apply_game_rules(apply_gravity(grid))
      combos += new_combos
      score += score
    end

    score = combos.map { |c| SCORES[c] }.reduce(:+).to_f * empty_ratio
    [grid, combos, score]
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
