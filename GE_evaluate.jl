push!(LOAD_PATH, "../Grammatical-evolution")

import RockSample
import GE_PolicyFunctions
import ForwardDiff

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

function calc_fitness_pw4(rs, params, steplimit)
  is_collected = falses(8)

  while(!rs.Terminated && rs.Steps <= steplimit)
    # find closest rock that hasn't been collected and is above threshold
    nearest_rock = GE_PolicyFunctions.find_valid_rock2(rs, is_collected, params)

    # make sure there is a valid rock
    if nearest_rock > 0

      # collect rock
      is_collected[nearest_rock] = GE_PolicyFunctions.collect_rock(rs, nearest_rock, steplimit)

    # if none, move to exit
    else
      RockSample.move(rs,"East")
    end

  end
  return params
end

function main()
  games = 10000
  steplimit = 50

  #lambda = 0.9328
  #lambda = 0.91
  #lambda = 0.1
  params = [0.0343,0.9253]

  total_reward = 0
  #total_gradient = 0
  #total_gradient = zeros(2)
  vec = collect(0:0.01:1)

  f = open("GE_evaluate_results.txt","w")

  for i = 1:length(vec)

    lambda = vec[i]
    total_reward = 0

    for n = 1:games
      rs = RockSample.RSinit();
      max_reward = RockSample.getMaxReward(rs)

      #calc_fitness(rs, lambda, steplimit)
      #f(x::Vector) = calc_fitness_pw3(rs, x, steplimit)
      #f(lambda)

      calc_fitness_pw3(rs, lambda, steplimit)

      #j = ForwardDiff.jacobian(f)
      #jx = j(params)
      #println(jx)
      #jx = jx[1:size(jx)[1]+1:size(jx)[1]^2]
      ##println(jx)

      #total_gradient += jx
      total_reward += rs.Reward / max_reward
    end

    avg_reward = total_reward / games
    #println("Average reward: $(avg_reward)")

    #avg_gradient = total_gradient / games
    #println("Average gradient: $(avg_gradient)")
    write(f,"$(lambda),$(avg_reward)\n")

  end

  close(f)

  println("Done!")

end

main()