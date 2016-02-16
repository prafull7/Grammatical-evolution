push!(LOAD_PATH, "../Grammatical-evolution")

# Import GE library, RockSample simulator
using GrammaticalEvolution
import GrammaticalEvolution.evaluate!
import GrammaticalEvolution.isless
using RockSample
import Base

# define a rover individual
type roverIndividual <: Individual
  genome::Array{Int64, 1}
  fitness::Float64
  code

  function roverIndividual(size::Int64, max_value::Int64)
    genome = rand(1:max_value, size)
    return new(genome, -1, nothing)
  end

  roverIndividual(genome::Array{Int64, 1}) = new(genome, -1, nothing)
end

# define a poluation of rovers
type roverPopulation <: Population
  individuals::Array{roverIndividual, 1}

  function roverPopulation(individuals::Array{roverIndividual, 1})
    return new(copy(individuals))
  end

  function roverPopulation(population_size::Int64, genome_size::Int64)
    individuals = Array(roverIndividual, 0)
    for i=1:population_size
      push!(individuals, roverIndividual(genome_size, 1000))
    end

    return new(individuals)
  end
end

# macros for forming if / loop / blocks 
make_block(lst::Array) = Expr(:block, lst...)
make_loop(values::Array) = Expr(:for, :(=), :i, Expr(:(:), 1, values[1]), values[2])
make_if(values::Array) = Expr(:if, values[1], values[2], values[3])

macro make_if(condition, true_block, false_block)
  Expr(:if, condition, true_block, false_block)
end

macro make_call(fn, args...)
  Expr(:call, fn, args...)
end

macro make_for(start, stop, block)
  Expr(:for, Expr(:(=), :i, Expr(:(:), start, stop)), block)
end

convert_number(lst) = float(join(lst))

# grammars for problem
@grammar rover_grammar begin
  start = decimal

  command = goleft | goright | goup | godown | sample | check | for_loop | if_statement
  goleft = Expr(:call, :move, :rs, "West")
  goright = Expr(:call, :move, :rs, "East")
  goup = Expr(:call, :move, :rs, "North")
  godown = Expr(:call, :move, :rs, "South")
  sample = Expr(:call, :sample, :rs)
  check = Expr(:call, :check, :rs, rock)

  if_statement = Expr(:if, condition, block, block)
  condition = good_rock
  good_rock = Expr(:call, :is_good_rock, :rs, rock)
  #good_rock = Expr(:call, :check, rock) == "Good"
  #good_rock = Expr(:(==), Expr(:call, :check, :rs, rock), "Good")

  while_loop = Expr(:while, not_terminated, block)
  not_terminated = Expr(:call, :has_not_terminated, :rs)

  for_loop = Expr(:for, Expr(:(=), :i, Expr(:(:), 1, for_digit)), block)
  block[make_block] = (command)^(1:8)

  for_digit = 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9

  digit = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
  rock = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8

  reduced_digit = 0 | 1 | 2 | 3 | 4 | 5

  decimal[convert_number] = 0 + '.' + digit + digit
end

# function to check if simulation terminated
# extra condition added to make sure the loop terminates:
# can only call this function 100 times
@eval function has_not_terminated(rs::RS)
  count = $(zeros(1))
  if !rs.Terminated && count[1] < 100
    count[1] += 1
    return true
  else
    count[1] = 0
    return false
  end
end

# function to check for good rock
function is_good_rock(rs::RS, rock)
  if check(rs, rock) == "Good"
    return true
  else
    return false
  end
end

# function 1 to encode structure for the policy
# code that is evolved is run within a while loop
function policy_wrapper1(rs::RS, ind::roverIndividual)
  iteration = 0
  @eval fn(rs::RS) = $(ind.code)

  while(!rs.Terminated && iteration < 100)
    fn(rs)
    iteration += 1
  end
end

# function 2 to encode structure for the policy
# only a constant is evolved, which balances exploration / exploitation
function policy_wrapper2(rs::RS, ind::roverIndividual)
  iteration = 0
  @eval fn(rs::RS) = $(ind.code)
  lambda = fn(rs)

  is_collected = falses(8)

  while(!rs.Terminated)
    # find closest rock that hasn't been collected and is above threshold
    nearest_rock = find_valid_rock(rs, is_collected, lambda)

    # make sure there is a valid rock
    if nearest_rock > 0

      # collect rock
      collect_rock(rs, nearest_rock)
      is_collected[nearest_rock] = true

    # if none, move to exit
    else
      move(rs,"East")
    end

    iteration += 1
  end

end

# function to find the closest rock that 
function find_valid_rock(rs::RS, is_collected, lambda)
  distances = Inf*ones(8)

  for i in collect(1:8)
    if !is_collected[i]
      d = abs(rs.Robot.x - rs.Rocks[i].x) + abs(rs.Robot.y - rs.Rocks[i].y)
      nu = 2^(-d/rs.d0)
      accuracy = 0.5 + 0.5*nu

      if accuracy > lambda && check(rs,i) == "Good"
        distances[i] = d
      end

    end
  end

  if minimum(distances) == Inf
    return 0
  else
    return indmin(distances)
  end
end

# function to move robot to rock to sample it
function collect_rock(rs::RS, rock)
  while(true)

    dx = rs.Robot.x - rs.Rocks[rock].x
    dy = rs.Robot.y - rs.Rocks[rock].y

    if dx < 0
      move(rs,"East")
    elseif dx > 0
      move(rs,"West")
    elseif dy < 0
      move(rs,"South")
    elseif dy > 0
      move(rs,"North")
    end

    if rs.Robot.x == rs.Rocks[rock].x && rs.Robot.y == rs.Rocks[rock].y
      sample(rs)
      return
    end

  end

end

# function to make a RockSample copy 
function copyRS(rs::RS)
  rs_copy = RSinit();
  rs_copy.Rocks = rs.Rocks # don't reinitialize the rocks randomly every evaluation call
  return rs_copy
end

# evaluation function to determine fitness
function evaluate!(grammar::Grammar, ind::roverIndividual, rs::RS)
  # copy simulation instance
  rs = copyRS(rs);

  # generate code
  try
    ind.code = transform(grammar, ind)
    #@eval fn(rs::RS, ind::roverIndividual) = $(ind.code)
    #@eval fn(rs::RS, ind::roverIndividual) = policy_wrapper1(rs, ind)
    @eval fn(rs::RS, ind::roverIndividual) = policy_wrapper2(rs, ind)
  catch e
    #if typeof(e) !== MaxWrapException
    #  Base.error_show(STDERR, e, catch_backtrace())
    #end
    ind.fitness = -Inf
    return
  end

  # run code
  fn(rs, ind)

  ind.fitness = convert(Float64, rs.Reward)

  return ind.fitness
end

# need to redefine 'isless' (more reward is better)
isless(ind1::roverIndividual, ind2::roverIndividual) = ind1.fitness > ind2.fitness

function main()

  # create simulation instance
  rs = RSinit();

  # create population
  pop = roverPopulation(500, 500)

  fitness = 0
  generation = 1

  evaluate!(rover_grammar, pop, rs)
  while generation <= 100
    # generate a new population (based off of fitness)
    pop = generate(rover_grammar, pop, 0.1, 0.2, 0.2, rs)

    # population is sorted, so first entry it the best
    fitness = pop[1].fitness
    println("-------------------------------------------------------------")
    println("generation: $generation, $(length(pop)), max fitness=$fitness\n$(pop[1].code)")
    generation += 1
  end

end

main()
