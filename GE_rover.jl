push!(LOAD_PATH, "../Grammatical-evolution")

# Import GE library, RockSample simulator
using GrammaticalEvolution
import GrammaticalEvolution.evaluate!
import GrammaticalEvolution.isless
import RockSample
import GE_PolicyFunctions

println("[GE_rover] Loaded libraries")

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

function params2(a,b)
  return a,b
end

function move(rs,direction)
  RockSample.move(rs,direction)
end

function sample(rs)
  RockSample.sample(rs)
end

function check(rs,rock)
  RockSample.check(rs,rock)
end

function is_good_rock(rs,rock)
  return GE_PolicyFunctions.is_good_rock(rs,rock)
end

function high_belief(rs,rock,threshold)
  if rs.Belief[rock] >= threshold
    return true
  else
    return false
  end
end

# grammars for problem
@grammar rover_grammar begin
  start = block

  block[make_block] = (command)^(1:7)

  command = goleft | goright | goup | godown | sample | check | if_statement #| for_loop
  params2 = Expr(:call, :params2, decimal, decimal)
  goleft = Expr(:call, :move, :rs, "West" )
  goright = Expr(:call, :move, :rs, "East")
  goup = Expr(:call, :move, :rs, "North")
  godown = Expr(:call, :move, :rs, "South")
  sample = Expr(:call, :sample, :rs)
  check = Expr(:call, :check, :rs, rock)

  if_statement = Expr(:if, condition, block)
  condition = good_rock | high_belief
  good_rock = Expr(:call, :is_good_rock, :rs, rock)
  belief = Expr(:call, :belief, :rs, rock, decimal)
  #good_rock = Expr(:call, :check, rock) == "Good"
  #good_rock = Expr(:(.==), Expr(:call, :check, :rs, rock), "Good")

  while_loop = Expr(:while, not_terminated, block)
  not_terminated = Expr(:call, :has_not_terminated, :rs)

  for_loop = Expr(:for, Expr(:(=), :i, Expr(:(:), 1, for_digit)), block)

  rock = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8
  for_digit = 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
  digit = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
  reduced_digit = 5 | 6 | 7 | 8 | 9

  decimal[convert_number] = 0 + '.' + digit + digit
end

# function 1 to encode structure for the policy
# code that is evolved is run within a while loop
function policy_wrapper1(rs::RockSample.RS, ind::roverIndividual)
  iteration = 0
  steplimit = 50

  @eval fn(rs::RockSample.RS) = $(ind.code)

  while(!rs.Terminated && iteration <= 1)
    fn(rs)
    iteration += 1
  end
  return 
end

# function 2 to encode structure for the policy
# only a constant is evolved, which balances exploration / exploitation
function policy_wrapper2(rs::RockSample.RS, ind::roverIndividual)
  iteration = 0
  @eval fn(rs::RockSample.RS) = $(ind.code)
  lambda = fn(rs)

  #println(lambda)

  if typeof(lambda) != Float64
    rs.Reward = -Inf
    return
  end

  is_collected = falses(8)

  while(!rs.Terminated)
    # find closest rock that hasn't been collected and is above threshold
    nearest_rock = GE_PolicyFunctions.find_valid_rock(rs, is_collected, lambda)

    # make sure there is a valid rock
    if nearest_rock > 0

      # collect rock
      GE_PolicyFunctions.collect_rock(rs, nearest_rock)
      is_collected[nearest_rock] = true

    # if none, move to exit
    else
      while(!rs.Terminated)
        move(rs,"East")
      end
    end

    iteration += 1
  end
  return
end

# function 3 to encode structure for the policy
# improvements on version 2, which is based on an accuracy threshold 
function policy_wrapper3(rs::RockSample.RS, ind::roverIndividual)
  @eval fn(rs::RockSample.RS) = $(ind.code)
  lambda = fn(rs)

  if typeof(lambda) != Float64
    rs.Reward = -Inf
    return
  end

  is_collected = falses(8)
  steplimit = 50

  while(!rs.Terminated && rs.Steps <= steplimit)
    # find closest rock that hasn't been collected and is above threshold
    nearest_rock = GE_PolicyFunctions.find_valid_rock(rs, is_collected, lambda)

    # make sure there is a valid rock
    if nearest_rock > 0

      # collect rock
      is_collected[nearest_rock] = GE_PolicyFunctions.collect_rock(rs, nearest_rock, steplimit)

    # if none, move to exit
    else
      RockSample.move(rs,"East")
    end

  end
  return
end

# function 4 to encode structure for the policy
# parameterized by belief threshold 
function policy_wrapper4(rs::RockSample.RS, ind::roverIndividual)
  @eval fn(rs::RockSample.RS) = $(ind.code)
  gamma = fn(rs)

  if typeof(gamma) != Float64
    rs.Reward = -Inf
    return
  end

  is_collected = falses(8)
  steplimit = 50

  while(!rs.Terminated && rs.Steps <= steplimit)
    # find closest rock that hasn't been collected and is above threshold
    nearest_rock = GE_PolicyFunctions.find_valid_rock2(rs, is_collected, gamma)

    # make sure there is a valid rock
    if nearest_rock > 0

      # collect rock
      is_collected[nearest_rock] = GE_PolicyFunctions.collect_rock(rs, nearest_rock, steplimit)

    # if none, move to exit
    else
      RockSample.move(rs,"East")
    end

  end
  return
end

# evaluation function to determine fitness
function evaluate!(grammar::Grammar, ind::roverIndividual)
  # copy simulation instance
  # rs = copyRS(rs);

  # generate code
  try
    ind.code = transform(grammar, ind)
    @eval fn(rs::RockSample.RS, ind::roverIndividual) = $(ind.code)
    #@eval fn(rs::RockSample.RS, ind::roverIndividual) = policy_wrapper1(rs, ind)
    #@eval fn(rs::RockSample.RS, ind::roverIndividual) = policy_wrapper2(rs, ind)
    #@eval fn(rs::RockSample.RS, ind::roverIndividual) = policy_wrapper3(rs, ind)
    #@eval fn(rs::RockSample.RS, ind::roverIndividual) = policy_wrapper4(rs, ind)
  catch e
    #if typeof(e) !== MaxWrapException
    #  Base.error_show(STDERR, e, catch_backtrace())
    #end
    ind.fitness = -Inf
    return
  end

  n_games = 50
  total = 0
  # run code
  # averaged over multiple games
  for i = 1:n_games
    # generate new instance
    rs = RockSample.RSinit();
    max_reward = RockSample.getMaxReward(rs)

    # evaluate instance
    # fn(rs, ind)
    fn(rs, ind)

    # get reward
    total += (rs.Reward / max_reward)

  end

  avg_reward = total / n_games

  code_string = convert(ASCIIString,string(ind.code))
  sub_strings = split(code_string,"\n")
  program_length = length(sub_strings) - 2

  if program_length > 25
    avg_reward -= 0.1
  end
  
  ind.fitness = avg_reward
end

function ParseCode(code)
  # break up the code into strings without spaces
  code_string = convert(ASCIIString,string(code))
  sub_strings = split(code_string,"\n")
  for i = 1:length(sub_strings)
    sub_strings[i] = strip(sub_strings[i])
  end

  # list of valid actions
  valid = ["North", "East", "South", "West", "sample", "check", "if", "end"]
  total_strings = length(sub_strings)

  line = 2
  input_list = ASCIIString[]
  while line <= total_strings - 1

    push!(input_list, sub_strings[line])

    #for j = 1:length(valid)
    #  string = sub_strings[line]
    #  res = search(string, valid[j])

     # if isempty(convert(Array,res))
     #   continue
     # end

      #if valid[j] == "check"
      #  for i = 1:8
      #    res = search(string,"$(i)")
      #
      #    if isempty(convert(Array,res))
      #      continue
      #    end
      #
      #    push!(input_list, "$(check)/$(i)")
      #  end
      #  continue
      #end

      #if valid[j] == "if"
      #  push!(input_list, "$(valid[j])/$(string[4:end])")
      #  continue
      #end

      #push!(input_list, valid[j])

    #end
    line += 1

  end

  println(input_list)

  return input_list
end

# need to redefine 'isless' (more reward is better)
isless(ind1::roverIndividual, ind2::roverIndividual) = ind1.fitness > ind2.fitness

function main()

  # create simulation instance
  #rs = RSinit();
  #println("Max possible reward: $(rs.RewardMax)")

  # create population
  # X individuals with genome Y elements long
  pop = roverPopulation(500,500)

  fitness = 0
  generation = 1
  max_generation = 25

  println("[GE_rover] Starting grammatical evolution ...")

  #evaluate!(rover_grammar, pop, rs)
  evaluate!(rover_grammar, pop)
  while generation <= max_generation
    # generate a new population (based off of fitness)
    pop = generate(rover_grammar, pop, 0.1, 0.2, 0.2)

    # population is sorted, so first entry it the best
    fitness = pop[1].fitness
    println("-------------------------------------------------------------")
    println("generation: $generation, $(length(pop)), max fitness=$fitness\n$(pop[1].code)")

    code_string = convert(ASCIIString,string(pop[1].code))
    sub_strings = split(code_string,"\n")
    program_length = length(sub_strings) - 2
    println("Program length: $(program_length)")


    #input_list = ParseCode(pop[1].code)
    #print(input_list)
    #println(pop[1].genome)
    #println(pop[1].code[1])
    #println(dump(pop[1].code))
    #println(length(pop[1].code.args))
    generation += 1
  end

  println("[GE_rover] Finished policy evolution")

  # 

end

main()
