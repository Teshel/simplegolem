
Config = {
	:plant_spread_cost => 10,
	:plant_age_max => 300,
	:photosynth => 1,
	:mob_reproduce_cost => 10,
	:mob_initial_resources => 10,
	:mob_reproduce_age => 50,
	:mob_age_max => 200,
	:resource_max => 100,
	:plant_density_max => 1
}

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

	def width
		@x
	end

	def height
		@y
	end
end

class GameManager < GridManager
	attr_accessor :plants, :mobs

	def initialize(x, y)
		super(x, y, Square)
		@world = @grid
		@mobs = []
		@plants = []
	end

	def run(n=100000)
		n.times do |i|
			step
			system 'clear'
			puts "(#{i})\t#{plants.length} plants\t#{mobs.length} mobs"
			display
			mobs.sort_by{|e| e.children.length}.reverse[0..0].each do |mob|
				mob.display_stats
			end
		end
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
		puts "-"*@x
	end

	def step
		step_plants
		step_mobs
	end

	def step_plants
		# plants gather energy and spread if possible
		@plants.each do |plant|
			plant.photosynth
			plant.spread
			plant.age += 1
			if plant.age >= Config[:plant_age_max]
				plant.die
			end
		end
		nil
	end

	def step_mobs
		# mobs now move to new places
		@mobs.each do |mob|
			mob.move_random
			mob.tire
			mob.age += 1
			if mob.age >= Config[:mob_age_max]
				mob.die
			end
		end

		# now battle and search for resources
		# and reproduce
		@mobs.each do |mob|
			# need to find an opponent
			other_mobs = mob.point.entities.find_all{|e|e.type == :mob and e != mob and e != mob.parent and mob.children.include?(e) == false}
			if other_mobs.length >= 1
				opponent = other_mobs.random
				battle(mob, opponent)
			end

			# gather and recuperate
			if mob.alive
				local_plants = mob.point.entities.find_all{|e| e.type == :plant and e.alive}
				# local_plants.each do |plant|`
				# 	mob.resources += plant.resources
				# 	plant.die
				# end
				if local_plants.length > 0
					plant = local_plants.random
					mob.add_resources(plant.resources/2)
					#plant.resources = 0
					plant.die
				end
				mob.heal
				mob.regen_mana(1)
				mob.reproduce
			end
		end
		nil
	end

	def battle(mob1, mob2)
		if rand(2) == 1
			first = mob1
			second = mob2
		else
			first = mob2
			second = mob1
		end

		#i = 1
		while (first.alive and second.alive)
			#puts "Turn #{i}"
			
			#first.display_stats
			#second.display_stats

			first.attack(second)
			if second.alive
				second.attack(first)
			end
			#i += 1
			#sleep 0.1
		end
		if first.alive
			first.add_resources(second.resources/2)
			first.kills += 1
		else
			second.add_resources(first.resources/2)
			second.kills += 1
		end
	end
end


class Entity
	attr_accessor :can_fight, :alive, :display_priority, :point, :type, :resources, :age
	def initialize(world, point)
		@world = world
		@point = point
		@name_list ||= []
		@name_id = rand(@name_list.length)
		@can_fight = false
		@alive = true
		@resources = 5
		@type = :none
		@age = 0
	end

	def display
		@name_list[@name_id]
	end

	def display_stats
		puts "(#{@point.x}, #{@point.y}) #{display} #{@resources} resources"
		nil
	end

	def add_resources(amount)
		@resources += amount
		if @resources > Config[:resource_max]
			@resources = Config[:resource_max]
		end
	end
end

class Plant < Entity
	PLANT_NAMES = ("a".."z").to_a

	def initialize(world, point, parent_id=nil)
		@name_list = PLANT_NAMES
		super(world, point)
		@type = :plant
		if parent_id
			@name_id = parent_id
		end
		@display_priority = 2
	end

	def photosynth
		@resources += Config[:photosynth]
	end

	def spread
		if @resources >= Config[:plant_spread_cost] * 2
			sparse_adjacents = @world.possible_adjacent(@point).find_all {|square| square.entities.find_all{|e|e.type == :plant}.length < Config[:plant_density_max]}
			if sparse_adjacents.length > 0
				square = sparse_adjacents.random
				plant = Plant.new(@world, square)
				square.entities.push plant
				@world.plants.push plant
				@resources -= Config[:plant_spread_cost]
			end
		end
	end

	def die
		@alive = false
		@world.plants.delete(self)
		@point.entities.delete(self)
	end
end

class Mob < Entity
	attr_accessor :health, :max_health, :genome, :mana, :attack_power, :healing_power, :kills, :parent, :children
	MOB_NAMES = ("A".."Z").to_a
	MOB_GENES = [:up, :down, :left, :right, :red, :black, :green, :blue]

	def initialize(world, point, parent=nil)
		@name_list = MOB_NAMES
		super(world, point)
		@type = :mob
		@display_priority = 1
		@can_fight = true
		@kills = 0
		@parent = parent

		@health = 10
		@max_health = 10
		@mana = 0
		@max_mana = 0
		@resources = Config[:mob_initial_resources]
		@children = []
		
		if parent
			mutate(parent.genome)
		else
			@genome = Array.new(5) { MOB_GENES.random }
		end
		@rune_power = {:black => 0, :blue => 0, :red => 1, :green => 0}
		@gm = GridManager.new(30, 10, RuneSquare)
		@abilities = [:attack]
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

	def tire
		unless use_resources(1)
			die
		end
	end

	def die
		if @alive
			@alive = false
			@children.each do |child|
				child.parent = nil
			end
			@children = nil
			@parent = nil
			@world.mobs.delete(self)
			@point.entities.delete(self)
		end
	end

	def mutate(parent_genome)
		@genome = parent_genome.dup
		case rand(5)
		when 0
			@genome[rand(@genome.length)] = MOB_GENES.random
		when 1
			@genome.insert(rand(@genome.length), MOB_GENES.random)
		when 2
			@genome.delete_at(rand(genome.length))
		end
	end

	def run_genes
		cursor = Point.new(@gm.width/2, @gm.height/2)
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
		# determine powers based on the grid
		@gm.grid.each do |row|
			row.each do |point|
				same_rune_adjacents = @gm.possible_adjacent(point).delete_if {|adj| adj.rune != point.rune}
				other_rune_adjacents = @gm.possible_adjacent(point).delete_if {|adj| adj.rune == point.rune}
				if same_rune_adjacents.length <= 2 and other_rune_adjacents.length > 0
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

		# apply power to stats
		increase_health(@rune_power[:black]*10)
		increase_mana(@rune_power[:blue])
		@attack_power = @rune_power[:red]
		@healing_power = @rune_power[:green]*3

		if @attack_power == 0
			@attack_power = 1
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

	def heal
		@health += @healing_power/2
		if @health > @max_health
			@health = @max_health
		end
	end

	def regen_mana(amount)
		@mana += amount
		if @mana > @max_mana
			@mana = @max_mana
		end
	end

	def use_mana(amount)
		if @mana - amount < 0
			return false
		else
			@mana -= amount
			return true
		end
	end

	def use_resources(amount)
		if @resources - amount < 0
			return false
		else
			@resources -= amount
			return true
		end
	end

	def reproduce
		if (@age >= Config[:mob_reproduce_age]) and (@resources >= ((@genome.length/2).round + Config[:mob_reproduce_cost] * 2))
			empty_adjacents = @world.possible_adjacent(@point).find_all {|square| square.entities.find_all{|e|e.type == :mob}.length < 1}
			if empty_adjacents.length > 0
				square = empty_adjacents.random
				child = Mob.new(@world, square, self)
				@children.push child
				square.entities.push child
				@world.mobs.push child
				@resources -= Config[:mob_reproduce_cost]
				@resources -= (@genome.length/2).round + Config[:mob_reproduce_cost]
			end
		end
	end

	def take_damage(amount)
		if amount > @health
			die
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
				# if successful using mana, then heal
				heal
			else
				# default to attacking when no mana
				other_mob.take_damage(@attack_power)
			end
		end
		# switch to the next ability
		@current_ability_id = (@current_ability_id + 1) % @abilities.length
	end

	def display_stats
		super
		puts "#{@health}/#{@max_health} health, #{@mana}/#{@max_mana} mana; #{@attack_power} attack power, #{@healing_power} healing power"
		runes = {:green => "G", :blue => "B", :red => "E", :black => "K", :none => " "}
		m = {:up => "U", :down => "D", :right => "R", :left => "L", :green => "G", :green => "G", :blue => "B", :red => "E", :black => "K"}
		puts "Genome: " + @genome.map{|gene| m[gene]}.join + " Children: #{@children.length}"

		puts("_"*@gm.width)
		@gm.grid.each do |row|
			row.each do |square|
				print runes[square.rune]
			end
			puts "|"
		end
		puts("-"*@gm.width)
	end
end

def test_gm
	gm = GameManager.new(60, 20)
	gm.populate_mobs(20)
	gm.populate_plants(200)
	gm.display
	gm
end

# test plant growth
def test_pg(n=100)
	gm = test_gm
	n.times do
		system 'clear'
		gm.step_plants
		gm.display
		sleep 0.1
	end
	gm
end


# test mob movement
def test_mm(n=100)
	gm = test_gm
	n.times do |i|
		gm.step_mobs
		system 'clear'
		puts "(#{i})"
		gm.display
		gm.mobs.sort_by{|e| e.resources}.reverse[0..4].each do |mob|
			mob.display_stats
		end
		sleep 0.1
	end
	gm
end

def test_all(n=100000)
	gm = test_gm
	gm.run(n)
	gm
end