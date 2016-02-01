
# gridSize hold the width and height of the grid
type sizeOfGrid
    W
    H
end

# State is storing the (x,y) coordinates defining a state of an object
type robot
    x
    y
    r
end

type Rock
    x
    y
    v
end

# Action is storing the direction which can be :left, :right, :up, :down
type Action
    direction
end
# The grid coordinates look as follows
# (1,1) (2,1) (3,1) .....
# (1,2) (2,2) (3,2) .....
# (1,3) (2,3) (3,3) .....
#   .     .     .
#   .     .     .
#   .     .     .


# gridS is storing the size of the grid
gridS = sizeOfGrid(7,8)

# rocks is an array having the (x, y) of the rocks in the environment
rocks = [Rock(1,6,0), Rock(2,1,0), Rock(3,3,0), Rock(3,7,0), Rock(4,3,0), 
    Rock(4,6,0), Rock(6,2,0), Rock(7,4,0)]

# roboS is the state of the robot. Below is the initial state of the robot.
roboS = robot(1,4, 0)
randomVals = rand(Bool,1,8)

for(i in [1:8])
    println(randomVals[i])
    if(randomVals[i] == true)
        rocks[i].v = 1
    else
        rocks[i].v = 0
    end
end


rocks


function move(roboS, direction)
    if(direction == :left)
        roboS.x -= 1 
    end
    
    if(direction == :right)
        roboS.x += 1 
    end
    
    if(direction == :up)
        roboS.y -= 1 
    end
    
    if(direction == :down)
        roboS.y += 1 
    end
end


function sample(roboS, rocks)
    for(r in rocks)
        if(r.x == roboS.x && r.y == roboS.y)
            if(r.v == 0)
                roboS.r -= 10
            else
                roboS.r += 10
                r.v = 0
            end
            return roboS
        end
    end
    return roboS
end


#function check(roboS, rocks, rockID)
    

roboS

move(roboS, :right)

roboS


