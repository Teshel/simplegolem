Config = {
	:resource_max => 100000,
	:mob_density_max => 1
}

class Array
	def random
		self[rand(self.length)]
	end
end

class Point
	attr_accessor :x, :y

	def initialize(x, y, grid)
		@x = x
		@y = y
		@grid = grid
	end

	def +(other_point)
		@grid.at(other_point.x + @x, other_point.y + @y)
	end
end

class Square < Point
	attr_accessor :entities

	def initialize(x, y, grid)
		super(x, y, grid)
		@entities = []
	end
end

class GridManager
	attr_accessor :grid, :bases, :mobs

	def initialize(x, y)
		@x = x
		@y = y
		@adjacents = [p(-1, -1), p(-1, 0), p(0, -1),
					  p(1, 1), p(1, 0), p(0, 1),
					  p(-1, 1), p(1, -1)]
		@grid = Array.new(y) { |y_| Array.new(x) {|x_| Square.new(x_, y_, self)} }
		@bases = []
		@mobs = []
	end

	def possible_adjacent(point)
		return_adjacents = []
		@adjacents.each do |adj|
			new_point = point + adj

			if in_bounds(new_point)
				return_adjacents.push(at(new_point))
			end
		end
		return return_adjacents
	end

	def in_bounds(point)
		(point.x >= 0) and (point.y >= 0) and
				(point.x < @x) and (point.y < @y)
	end

	def at(x, y)
		@grid[y][x]
	end

	def width
		@x
	end

	def height
		@y
	end
end

class Entity
	attr_accessor :can_fight, :alive, :display_priority, :point, :type, :resources, :age
	def initialize(grid, point)
		@grid = grid
		@point = point
		@name_list ||= []
		@name_id = rand(@name_list.length)
		@alive = true
		@resources = 0
		@type = :none
		@age = 0
	end

	def display
		@name_list[@name_id]
	end

	def display_stats
		#puts "(#{@point.x}, #{@point.y}) #{display} #{@resources} resources"
		nil
	end

	def add_resources(amount)
		@resources += amount
		if @resources > Config[:resource_max]
			@resources = Config[:resource_max]
		end
	end
end

class Mob < Entity
	def initialize(grid, point)
		@name_list = ("a".."z").to_a
		super(grid, point)
		@type = :mob
	end
end

class Base < Entity
	def initialize(grid, point)
		@name_list = ("A".."Z").to_a
		super(grid, point)
		@type = :base
	end
end

def test_grid

end

def test_mob

end