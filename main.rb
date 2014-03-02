class Array
	def random
		self[rand(self.length)]
	end
end

class Point
	attr_accessor :x, :y

	def initialize(x, y)
		@x = x
		@y = y
	end

	def +(other_point)
		Point.new(other_point.x + @x, other_point.y + @y)
	end
end

class Square < Point
	attr_accessor :entities

	def initialize(x, y)
		super(x, y)
		@entities = []
		@resources = []
	end
end

class RuneSquare < Point
	attr_accessor :rune

	def initialize(x, y)
		super(x, y)
		@rune = :none
	end
end

def p(x, y)
	Point.new(x, y)
end

class GridManager
	attr_accessor :grid

	ADJACENTS = [p(-1, -1), p(-1, 0), p(0, -1),
					p(1, 1), p(1, 0), p(0, 1),
					p(-1, 1), p(1, -1)]

	def initialize(x, y, default_square)
		@x = x
		@y = y
		@grid = Array.new(y) { |y_| Array.new(x) {|x_| default_square.new(x_, y_)} }
	end

	def possible_adjacent(point)
		return_adjacents = []
		ADJACENTS.each do |adj|
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

	def at(point)
		@grid[point.y][point.x]
	end
end

class GameManager < GridManager
	def initialize(x, y)
		super(x, y, Square)
		@world = @grid
		@mobs = []
		@plants = []
	end

	def populate_mobs(n=10)
		n.times do
			x = rand(@x)
			y = rand(@y)
			entity = Mob.new(self, @world[y][x])
			@world[y][x].entities.push entity
			@mobs.push entity
		end
	end

	def populate_plants(n=10)
		n.times do
			x = rand(@x)
			y = rand(@y)
			entity = Plant.new(self, @world[y][x])
			@world[y][x].entities.push entity
			@plants.push entity
		end
	end

	def display
		puts "_"*@x
		@world.reverse.each do |row|
			row.each do |square|
				if square.entities.length > 0
					print square.entities.sort_by {|entity| entity.display_priority}.first.display
				else
					print " "
				end
			end
			puts "|"
		end
	end

	def step
		# plants gather energy and spread if possible
		@plants.each do |plant|
			plant.photosynth
			plant.spread
		end

		# mobs now move to new places
		@mobs.each do |mob|
			mob.move_random
		end

		# now battle and search for resources
		# and reproduce
		@mobs.each do |mob|
			if mob.alive and mob.point.entities.length > 1
				# need to find an opponent
				opponent = mob.point.entities.find {|m| m != mob and m.alive}
				battle(mob, opponent)
				mob.reset_mana
			end

			# gather
			if mob.alive

			end
		end
	end

	def battle(mob1, mob2)
		if rand(2) == 1
			first = mob1
			second = mob2
		else
			first = mob2
			second = mob1
		end

		while (first.alive and second.alive)
			first.attack(second)
			if second.alive
				second.attack(first)
			end
		end
	end
end


class Entity
	attr_accessor :can_fight, :alive, :display_priority
	def initialize(world, point)
		@world = world
		@point = point
		@name_list ||= []
		@name_id = rand(@name_list.length)
		@can_fight = false
		@alive = true
		@resources = 0
	end

	def display
		@name_list[@name_id]
	end
end

class Plant < Entity
	attr_accessor :resources
	PLANT_NAMES = ("a".."z").to_a

	def initialize(world, point)
		@name_list = PLANT_NAMES
		super(world, point)

		@display_priority = 0
	end

	def photosynth
		@resources += 1
	end

	def spread
		if @resources >= 10
			most_sparse_adjacent = @world.possible_adjacent(@point).sort_by {|square| square.plants.length}.first
			if most_sparse_adjacent < 5
				most_sparse_adjacent.plants.push Plant.new(@world, most_sparse_adjacent)
				@resources -= 10
			end
		end
	end
end

class Mob < Entity
	attr_accessor :health, :max_health, :genome, :mana
	MOB_NAMES = ("A".."Z").to_a
	MOB_GENES = [:up, :down, :left, :right, :red, :black, :green, :blue]

	def initialize(world, point, parent=nil)
		@name_list = MOB_NAMES
		super(world, point)
		@health = 10
		@max_health = 10
		@mana = 0
		@max_mana = 10
		@display_priority = 1
		@can_fight = true
		if parent
			mutate(parent.gene)
		else
			@genome = Array.new(5) { MOB_GENES.random }
		end
		@rune_power = {:black => 0, :blue => 0, :red => 0, :green => 0}
		@gm = GridManager.new(10, 10, RuneSquare)
		@abilities = []
		@current_ability_id = 0
		run_genes
		calc_power
	end

	def move_random
	 	move_to(@world.possible_adjacent(@point).random)
	end

	def move_to(point)
		@point.entities.delete(self)
		point.entities.push(self)
		@point = point
	end

	def mutate(parent_genome)
		@genome = parent_genome.dup
		@genome[rand(@genome.length)] = MOB_GENES.random
	end

	def run_genes
		cursor = Point.new(0, 0)
		@genome.each do |gene|
			case gene
			when :up
				up = Point.new(1, 0) + cursor
				if @gm.in_bounds(up)
					cursor = up
				end
			when :down
				down = Point.new(-1, 0) + cursor
				if @gm.in_bounds(down)
					cursor = down
				end
			when :left
				left = Point.new(0, -1) + cursor
				if @gm.in_bounds(left)
					cursor = left
				end
			when :right
				right = Point.new(0, 1) + cursor
				if @gm.in_bounds(right)
					cursor = right
				end
			when :red
				@gm.at(cursor).rune = :red
			when :black
				@gm.at(cursor).rune = :black
			when :blue
				@gm.at(cursor).rune = :blue
			when :green
				@gm.at(cursor).rune = :green
			end

		end
	end

	def calc_power
		@gm.grid.each do |row|
			row.each do |point|
				same_rune_adjacents = @gm.possible_adjacent(point).delete_if {|adj| adj.rune != point.rune}
				if same_rune_adjacents.length <= 2
					power = same_rune_adjacents.length + 1
				else
					power = 0
				end
				if @rune_power[point.rune]
					@rune_power[point.rune] += power
				else
					@rune_power[point.rune] = 0
				end 
			end
		end

		increase_health(@rune_power[:black]||0)
		increase_mana(@rune_power[:blue]||0)
		@attack_power = @rune_power[:red]||0
		@healing_power = @rune_power[:green]||0
		if @attack_power > 0
			@abilities.push :attack
		end

		if (@healing_power > 0) and (@max_mana > 0)
			@abilities.push :heal
		end
	end

	def increase_health(amount)
		@health += amount
		@max_health += amount
	end

	def increase_mana(amount)
		@mana += amount
		@max_mana += amount
	end

	def use_mana(amount)
		if @mana - amount < 0
			return false
		else
			@mana -= amount
			return true
		end
	end

	def reproduce
		if @resources >= (@gene.length/5).round + 10
			most_sparse_adjacent = @world.possible_adjacent(@point).sort_by {|square| square.mobs.length}.first
			if most_sparse_adjacent < 5
				most_sparse_adjacent.plants.push Mob.new(@world, most_sparse_adjacent, self)
				@resources -= (@gene.length/5).round + 10
			end
		end
	end

	def take_damage(amount)
		if amount > @health
			@alive = false
			@point.entities.delete(self)
			return @health
		else
			@health -= amount
			return amount
		end
	end

	def attack(other_mob)
		case @abilities[@current_ability_id]
		when :attack
			other_mob.take_damage(@attack_power)
		when :heal
			if use_mana(2)
				@health += @healing_power/2
				if @health > @max_health
					@health = @max_health
				end
			else
				# default to attacking when no mana
				other_mob.take_damage(@attack_power)
			end
		end

		@current_ability_id = (@current_ability_id + 1) % @abilities.length
	end

	def display_stats

	end
end

def test_gm
	gm = GameManager.new(40, 20)
	gm.populate_mobs(10)
	gm.populate_plants(30)
	gm.display
	gm
end