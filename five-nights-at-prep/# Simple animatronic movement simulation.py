# Simple animatronic movement simulation

import time
import random

# Try out class
class Animatronic:
    def __init__(self, name, location, aggression):
        self.name = name
        self.location = location
        self.aggression = aggression
        self.movement_interval = 12 - self.aggression
        self.last_movement_check = time.monotonic()
      
freddy = Animatronic("Freddy", "Dining Area", 2)
bonnie = Animatronic("Bonnie", "Dining Area", 5)
chica = Animatronic("Chica", "Dining Area", 4)
    
animatronics = [freddy, bonnie, chica]

while True:
    current_time = time.monotonic()
    random_number = random.randint(1, 10)

    time.sleep(random_number)
    new_time = time.monotonic()
    elapsed_time = new_time - current_time
    
    # choose random to move check
    checkMove = random.choice(animatronics)
    aggressionCheck = checkMove.movement_interval
    
    if elapsed_time > aggressionCheck:
        print(f"{checkMove.name} moved!")
        
    else:
        print(f"""{checkMove.name}'s aggression of {aggressionCheck} was
        higher than the interval {elapsed_time:.2f}""")

    print(f"Elapsed time: {elapsed_time:.2f} seconds")
    print("")
    time.sleep(1)

