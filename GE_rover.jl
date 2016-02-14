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

# grammars for problem
@grammar rover_grammar begin
  start = if_statement

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

  for_loop = Expr(:for, Expr(:(=), :i, Expr(:(:), 1, digit)), block)
  while_loop = Expr(:while, false, block)
  block[make_block] = (command)^(1:5)

  digit = 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
  rock = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8

end

# function to check for good rock
function is_good_rock(rs::RS, rock)
  if check(rs, rock) == "Good"
    return true
  else
    return false
  end
end

# function to encode structure for the policy
function policy_wrapper(rs::RS,code)
  iteration = 0

  while(rs.reward <= 0 || iteration < 100)
    $(code)
    iteration += 1
  end
end

# function to make a RockSample copy 
function copyRS(rs::RS)
  rs_copy = RSinit();
  rs_copy.Rocks = rs.Rocks
  rs_copy.Reward = 0
  return rs_copy
end

# evaluation function to determine fitness
function evaluate!(grammar::Grammar, ind::roverIndividual, rs::RS)
  # create world
  rs = copyRS(rs);

  # generate code
  try
    ind.code = transform(grammar, ind)
    @eval fn(rs::RS) = $(ind.code)
    #@eval fn(rs::RS) = policy_wrapper(rs,ind.code)
  catch e
    #if typeof(e) !== MaxWrapException
    #  Base.error_show(STDERR, e, catch_backtrace())
    #end
    ind.fitness = -Inf
    return
  end

  # run code
  fn(rs)
  ind.fitness = convert(Float64, rs.Reward)
  #ind.fitness = rs.Reward
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
  while generation < 10
    # generate a new population (based off of fitness)
    pop = generate(rover_grammar, pop, 0.1, 0.2, 0.2, rs)

    # population is sorted, so first entry it the best
    fitness = pop[1].fitness
    println("generation: $generation, $(length(pop)), max fitness=$fitness\n$(pop[1].code)")
    generation += 1
  end

end

main()
