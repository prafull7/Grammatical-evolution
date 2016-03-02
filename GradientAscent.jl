push!(LOAD_PATH, "../Grammatical-evolution")

import RockSample
import GE_PolicyFunctions

function calc_fitness_pw3(rs, lambda, steplimit)
  is_collected = falses(8)

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

function main()
  games = 10000
  steplimit = 50

  error = Inf
  iter = 0

  l_old = 0.95
  v = 0
  gamma = 0.2
  eps = 0.01
  alpha = 0.05

  while error > 0.001
    alpha = alpha*exp(-iter/20)

    fitness = 0
    for n = 1:games
      rs = RockSample.RSinit();
      max_reward = RockSample.getMaxReward(rs)

      calc_fitness_pw3(rs, l_old, steplimit)

      fitness += rs.Reward / max_reward
    end
    Fl = fitness / games

    fitness = 0
    for n = 1:games
      rs = RockSample.RSinit();
      max_reward = RockSample.getMaxReward(rs)

      calc_fitness_pw3(rs, l_old+eps, steplimit)

      fitness += rs.Reward / max_reward
    end
    Fle = fitness / games

    gradF = (Fle - Fl) / eps

    if gradF > 1
      gradF = 1
    end
    if gradF < -1
      gradF = -1
    end

    #println(gradF)
    v = gamma*v + alpha*gradF
    l_new = l_old + v

    #if l_new > 1
    #  l_new = 1
    #end
    if l_new < 0
      l_new = 0
    end

    error = abs(l_new - l_old)
    l_old = l_new
    println("New paramter: $(l_new) with error: $(error)")

    iter += 1
  end

  println("Finished")

  fitness = 0
  for n = 1:games
    rs = RockSample.RSinit();
    max_reward = RockSample.getMaxReward(rs)

    calc_fitness_pw3(rs, l_old, steplimit)

    fitness += rs.Reward / max_reward
  end
  F = fitness / games
  println("Average fitness: $(F)")

end

main()