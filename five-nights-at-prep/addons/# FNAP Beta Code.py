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
            print(f"--- {self.name} moved to {rooms[self.location]}!")
            
        else:
            print(f"--- {self.name} did not move this time. Aggression: {self.aggression}, Time since last move: {elapsed_time:.2f} seconds")
            # print(f"Movement interval: {self.movement_interval} seconds (to check if {self.name} can move)")


    def check_movement(self):
        move_roll = random.randint(1, 10)

        if move_roll <= self.aggression:
            self.move()
        else:
            print(f"--- {self.name} failed movement check. Aggression: {self.aggression}, Roll: {move_roll}")


    # The check movement function will randomly determine if the animatronic will move based on its aggression level.


    def reset(self):
        self.location = self.movement_path[0]
        self.current_index = 0
        self.last_movement_time = time.monotonic()
        
    def add_aggression(self):
        self.aggression += 1
        print(f"Log: {self.name}'s aggression has increased to {self.aggression}")
        
        
    def decrease_movement_interval(self):
        self.movement_interval = max(1, self.movement_interval - 1)  # Decrease movement interval but not below 1 second
        print(f"Log: {self.name}'s movement interval has decreased to {self.movement_interval} seconds")

    
        
# Define Variables for Animatronics      
freddy = Animatronic("Freddy", 2, 2, freddy_movement_path)
bonnie = Animatronic("Bonnie", 2, 5, bonnie_movement_path)
chica = Animatronic("Chica", 2, 4, chica_movement_path) # the first 2 is the starting location, currently set to the bellermine (note for my future sanity)

# Grab the animatronics into a list for random selection
animatronics = [freddy, bonnie, chica]


# Start Night Setup & Reset Functions

def start_night():
    # Set Night Start Time
    night_start_time = time.monotonic() # Stores this variable out so it won't reset every loop
    office_power = 100 # Resets Office Power to 100% at the start of each night
    time_since_last_drain = 0 # Resets the time since last drain to 0 at the start of each night
    return night_start_time, office_power, time_since_last_drain

night_start_time, office_power, time_since_last_drain = start_night() # set variables (i actually dont think this is needed since alr defined in the loop)


# Define Night Durations
night_durations = {
    1: 360,
    2: 360,
    3: 360,
    4: 360,
    5: 360
}

# Set Night Initially
night = 1

# Clock Timer Functions

def convert_elapsed_to_time(elapsed_time):
     # Convert elapsed time into hours for clock
    total_seconds = int(elapsed_time)
    hours = total_seconds // 60
        
    if hours == 0:
        hours = 12 # Midnight
            
    return hours


# Power Drain Function

def drain_power_by_usage(usage, office_power):
    pass

# once we have a working door / camera system this function will have to be defined to check the usage rate and then drain power accordingly. 
# Until we integrate into the game, I will keep the power drain static.



# All Animatronic Functions

def animatronic_reset():
    for animatronic in animatronics:
        animatronic.reset()
        
        
def all_animatronics_add_aggression():
    for animatronic in animatronics:
        animatronic.add_aggression()
        
        
def all_animatronic_movement_check():
    for animatronic in animatronics:
        animatronic.check_movement()
        
def all_animatronics_decrease_movement_interval():
    for animatronic in animatronics:
        animatronic.decrease_movement_interval()







# -------- Main Game Loop: Will run for now, more features will be added later.

while True:


    # Check Elapsed Time Since Start
    elapsed_time = time.monotonic() - night_start_time
    
    hours = convert_elapsed_to_time(elapsed_time)

    # Check Power Drain Status
    if time_since_last_drain >= 10:
        office_power-= 1
        time_since_last_drain = 0
    
    # Display Current Game Status
    print("")
    print(f"Elapsed time since start: {elapsed_time:.2f} seconds")
    print(f"Current Night: {night}")
    print(f"Current Time: {hours} AM")
    print(f"Office Power: {office_power}%")
    print("")

    # Check if the current night is over
    if elapsed_time >= night_durations[night]: # Check if the elapsed time has exceeded the duration for current night
        print(f"Night {night} has ended!")
        night += 1
        if night > 5:
            print("All nights completed! Game Over!")
            break
        else:
            # START NEW NIGHT
            print(f"Starting Night {night}...")
            
            # Reset Time and Power
            night_start_time, office_power, time_since_last_drain = start_night()  # Reset the night start time for the new night

            # Reset Animatronics positions and timers
            animatronic_reset()
            all_animatronics_add_aggression() # Increase aggression for all animatronics by night - 1
            print("")
            all_animatronics_decrease_movement_interval() # Decrease movement interval for all animatronics by 1
            print("")


    # Else if the night is not over...

    # Perform Movement Check for All Animatronics
    all_animatronic_movement_check()
    time_since_last_drain += 1
    
    # Wait for a short period before the next movement check
    time.sleep(1)
    
    
    
    
# Dev note: 

    # next thing to do is integrate the camera and door system in the game loop and then change the power drain function accordingly
