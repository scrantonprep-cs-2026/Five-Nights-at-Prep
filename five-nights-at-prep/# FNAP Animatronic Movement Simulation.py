# FNAP Animatronic Movement Simulation [BETA 1.0]

import time
import random


# Movement Path Logic
rooms = {
    1: "Yondr Room",
    2: "Bellermine",
    3: "Admin",
    4: "Right Hall",
    5: "Left Hall",
    6: "Classroom1",
    7: "Classroom2",
    8: "Mrs. E's Room",
}

movement_path = [1, 2, 3, 4, 5, 6, 7, 8]  # This is not yet configured for our specific map, but it is a placeholder for now
current_index = 0


# Set Different Anaimatronic Movement Paths
freddy_movement_path = [2, 5, 3, 4]
bonnie_movement_path = [2, 5, 6, 7]
chica_movement_path = [2, 8, 3, 4]

# Dev Note: The current movement paths are just placeholders and are not yet configured for our specific map!!!!

# Define Class for Animatronic
class Animatronic:
    def __init__(self, name, location, aggression, movement_path):
        self.name = name
        self.location = location
        self.aggression = aggression
        self.movement_path = movement_path
        self.current_index = self.movement_path.index(self.location)
        self.movement_interval = 12 - self.aggression
        self.last_movement_time = time.monotonic()

    # Animatronic Moves
    def move(self):
        current_time = time.monotonic()
        elapsed_time = current_time - self.last_movement_time

        if elapsed_time >= self.movement_interval:
            # Move to the next location in the movement path
            self.current_index = (self.current_index + 1) % len(self.movement_path)
            self.location = self.movement_path[self.current_index]
            self.last_movement_time = current_time
            print(f"{self.name} moved to {rooms[self.location]}!")
            print("")
        else:
            print("")
            print(f"{self.name} is waiting to move. Aggression: {self.aggression}, Time since last move: {elapsed_time:.2f} seconds")
            print(f"Movement interval: {self.movement_interval} seconds (to check if {self.name} can move)") # Included for now to ensure that the movement interval is being calculated correctly.
            print("")


    def check_movement(self):
        move_roll = random.randint(1, 10)

        if move_roll <= self.aggression:
            self.move()
        else:
            print(f"{self.name} did not move this time. Aggression: {self.aggression}, Roll: {move_roll}")
            print("")

    # The check movement function will randomly determine if the animatronic will move based on its aggression level.


    def reset(self):
        self.location = self.movement_path[0]
        self.current_index = 0
        self.last_movement_time = time.monotonic()

    
        
# Define Variables for Animatronics      
freddy = Animatronic("Freddy", 2, 2, freddy_movement_path)
bonnie = Animatronic("Bonnie", 2, 5, bonnie_movement_path)
chica = Animatronic("Chica", 2, 4, chica_movement_path) # the first 2 is the starting location, currently set to the bellermine (note for my future sanity)

# Grab the animatronics into a list for random selection
animatronics = [freddy, bonnie, chica]





# ------- CURRENTLY IN PROGRESS SECTION -----------



# Start Night Setup & Reset Functions

def start_night():
    # Set Night Start Time
    night_start_time = time.monotonic() # Stores this variable out so it won't reset every loop
    return night_start_time

night_start_time = start_night() # Grabs a fixed timestamp


def animatronic_reset():
    for animatronic in animatronics:
        animatronic.reset()

# Define Night Durations
night_durations = {
    1: 120,
    2: 180,
    3: 240,
    4: 300,
    5: 360
}

# Set Night Initially
night = 1




# -------- Main Game Loop: Will run for now, more features will be added later.

while True:

    # Check Elapsed Time Since Start
    elapsed_time = time.monotonic() - night_start_time

    print("")
    print(f"Elapsed time since start: {elapsed_time:.2f} seconds")
    print("")

    # Check if the current night is over
    if elapsed_time >= night_durations[night]: # Check if the elapsed time has exceeded the duration for current night
        print(f"Night {night} has ended!")
        night += 1
        if night > 5:
            print("All nights completed! Game Over!")
            break
        else:
            print(f"Starting Night {night}...")


            night_start_time = start_night()  # Reset the night start time for the new night

            # Reset Animatronics positions and timers
            animatronic_reset()
            print("")


    # Else if the night is not over...

    # Randomly select an animatronic to move
    animatronic = random.choice(animatronics)
    animatronic.check_movement()
    
    # Wait for a short period before the next movement check
    time.sleep(3)