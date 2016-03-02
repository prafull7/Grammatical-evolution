module GE_PolicyFunctions

import RockSample
export has_not_terminated, is_good_rock, find_valid_rock, collect_rock, copyRS

# function to check if simulation terminated
# extra condition added to make sure the loop terminates:
# can only call this function 100 times
@eval function has_not_terminated(rs::RockSample.RS)
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
function is_good_rock(rs::RockSample.RS, rock)
  if RockSample.check(rs, rock) == "Good"
    return true
  else
    return false
  end
end

# function to find the closest rock for which the sensor is accurate enough
function find_valid_rock(rs::RockSample.RS, is_collected, lambda)
  distances = Inf*ones(8)

  for i = 1:8
    if !is_collected[i]
      d = abs(rs.Robot.x - rs.Rocks[i].x) + abs(rs.Robot.y - rs.Rocks[i].y)
      nu = 2^(-d/rs.d0)
      accuracy = 0.5 + 0.5*nu

      if accuracy > lambda
        if RockSample.check(rs,i) == "Good"
          distances[i] = d
        end
      end

    end
  end

  if minimum(distances) == Inf
    return 0
  else
    return indmin(distances)
  end
end


# function to find the closest rock based on belief
function find_valid_rock2(rs::RockSample.RS, is_collected, gamma)
  distances = Inf*ones(8)
  gamma = params[2]

  for i = 1:8
    if !is_collected[i]
      d = abs(rs.Robot.x - rs.Rocks[i].x) + abs(rs.Robot.y - rs.Rocks[i].y)
      nu = 2^(-d/rs.d0)
      acc = 0.5 + 0.5*nu

      # rs.Belief[i] = beta*rs.Belief[i] + (1-beta)*acc

      RockSample.check(rs,i)

      if rs.Belief[i] > gamma
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
function collect_rock(rs::RockSample.RS, rock, steplimit)
  while(rs.Steps <= steplimit)

    dx = rs.Robot.x - rs.Rocks[rock].x
    dy = rs.Robot.y - rs.Rocks[rock].y

    if dx < 0
      RockSample.move(rs,"East")
    elseif dx > 0
      RockSample.move(rs,"West")
    elseif dy < 0
      RockSample.move(rs,"South")
    elseif dy > 0
      RockSample.move(rs,"North")
    end

    if rs.Robot.x == rs.Rocks[rock].x && rs.Robot.y == rs.Rocks[rock].y
      RockSample.sample(rs)
      return true
    end

  end

  return false
end

# function to make a RockSample copy 
function copyRS(rs::RockSample.RS)
  rs_copy = RockSample.RSinit();
  rs_copy.Rocks = rs.Rocks # don't reinitialize the rocks randomly every evaluation call
  return rs_copy
end

end # module