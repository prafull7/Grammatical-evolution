
type RobotState
    x
    y
end

type Rock
    x
    y
    value
end

type RS
    d0
    Robot
    Belief
    Reward
    Rocks
    Actions
end
# ------------------------------------------------> x axis
#   (0,0) , (1,0), (2,0), (3,0), (4,0), (5,0) (6,0)
#   (0,1) , (1,1), (2,1), (3,1), (4,1), (5,1) (6,1)
#   (0,2) , (1,2), (2,2), (3,2), (4,2), (5,2) (6,2)
#   (0,3) , (1,3), (2,3), (3,3), (4,3), (5,3) (6,3)
#   (0,4) , (1,4), (2,4), (3,4), (4,4), (5,4) (6,4)
#   (0,5) , (1,5), (2,5), (3,5), (4,5), (5,5) (6,5)
#   (0,6) , (1,6), (2,6), (3,6), (4,6), (5,6) (6,6)


function RSinit()
    d0 = 20
    Rocks = [Rock(1,2, "Bad"), Rock(2,6, "Bad"), Rock(3,3, "Bad"), 
        Rock(3,4, "Bad"), Rock(4,7, "Bad"), Rock(6,1, "Bad"), 
        Rock(6,4, "Bad"), Rock(7,3, "Bad")]
    
    randomVals = rand(Bool,1,8)
    for(i in [1:8])
        println(randomVals[i])
        if(randomVals[i] == true)
            Rocks[i].value = "Good"
        end
    end
    Rewards = 0
    Actions = getActionSet(Rocks)
    Robot = RobotState(0,4)
    Belief = 0.5*ones(length(Rocks))
    return RS(d0, Robot, Belief, Rewards, Rocks, Actions)
end

function getActionSet(rp)
    A = ["North" "South" "East" "West" "Sample"]
    for i = 1:length(rp)
        A = hcat(A,"Check"*string(i))
    end
    return A
end

# Moving North => y -= 1
# Moving South => y += 1
# Moving West => x -= 1
# Moving East => x += 1
function move(RS, direction)
    posNew = deepcopy(RS.Robot)
    if direction == "North"
        posNew.y -= 1
    elseif direction == "South"
        posNew.y += 1
    elseif direction == "West"
        posNew.x -= 1
    elseif direction == "East"
        posNew.x += 1
    end
    
    if posNew.x > 6   # ends the game because the robot is in the end zone 
        RS.Reward += 10
        return "end";
    elseif posNew.x >= 0 && posNew.x <= 6 && posNew.y >= 0
        RS.Robot = posNew;
    else
        RS.Reward -= 100
    end
end

function sample(RS)
    for r in RS.Rocks
        if r.x == RS.Robot.x && r.y == RS.Robot.y
            if r.value == "Bad"
                RS.Reward -= 10
            else
                RS.Reward += 10
                r.value = "Bad"
            end
        end
    end
    println(RS.Reward)
end

# RS is the rocksample instance and number is the numberth 
# rock that we want to sample ranging from 1:8
function check(RS, number)
    rock = RS.Rocks[number]
    d = abs(RS.Robot.x - rock.x) + abs(RS.Robot.y - rock.y)
    nu = 2^(-d/RS.d0)
    pco = 0.5 + nu*0.5
    if rand() > pco
        if rock.value == "Good"
            return "Bad"
        elseif rock.value == "Bad"
            return "Good"
        end
    else
        return rock.value
    end            
end
