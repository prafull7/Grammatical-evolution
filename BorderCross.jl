# Implementation of a simple cooperative game involving two agents
# Agents are trying to cross a wall by helping each other over it

module BorderCross

export BC, BCinit, move, cooperate, call

type RobotState
  x
  y
end

type BC
    d0
    Robots
    Reward
    Terminated
    Steps
end

# ------------------------------------------------> x axis
#   (0,0) , (1,0), (2,0), (3,0), (4,0), (5,0), (6,0)
#   (0,1) , (1,1), (2,1), (3,1), (4,1), (5,1), (6,1)
#   (0,2) , (1,2), (2,2), (3,2), (4,2), (5,2), (6,2)
#   (0,3) , (1,3), (2,3), (3,3), (4,3), (5,3), (6,3)
#   (0,4) , (1,4), (2,4), (3,4), (4,4), (5,4), (6,4)
#   (0,5) , (1,5), (2,5), (3,5), (4,5), (5,5), (6,5)
#   (0,6) , (1,6), (2,6), (3,6), (4,6), (5,6), (6,6)

function BCinit()
  Steps = 0
  d0 = 20

  Reward = 0
  Terminated = false

  Robot1 = RobotState(0,3)
  Robot2 = RobotState(2,6)
  Robots = [Robot1, Robot2]

  return BC(d0, Robots, Reward, Terminated, Steps)
end

function move(BC, robot, direction)
  if BC.Terminated
    return "end"
  end

  posNew = deepcopy(BC.Robots[robot])
  if direction == "North"
    posNew.y -= 1
  elseif direction == "South"
    posNew.y += 1
  elseif direction == "West"
    posNew.x -= 1
  elseif direction == "East"
    posNew.x += 1
  end
  
  if posNew.x > 6 && posNew.y >= 0 && posNew.y <= 6
    BC.Steps += 1
    return
  elseif posNew.x >= 0 && posNew.x <= 6 && posNew.y >= 0 && posNew.y <= 6
    BC.Robots[robot] = posNew
  else
    BC.Reward -= 100
  end

  BC.Steps += 1
  return
end

function cooperate(BC)
  if BC.Robots[1].x == BC.Robots[2].x && BC.Robots[1].y == BC.Robots[2].y && BC.Robots[1].x == 6 && BC.Robots[1].y >= 0 && BC.Robots[1].y <= 6
    BC.Reward += 10
    BC.Terminated = true
    BC.Steps += 1
  else
    BC.Steps += 1
  end
  return
end

function call(BC, robot)
  d = abs(BC.Robots[robot].x - BC.Robots[3-robot].x) + abs(BC.Robots[robot].y - BC.Robots[3-robot].y)
  nu = 2^(-d/BC.d0)
  pco = 0.5 + nu*0.5

  if rand() > pco
    if rand() > 0.5
      d += 1
    else
      d -= 1
    end
  end

  BC.Steps += 1
  return d
end

end # module