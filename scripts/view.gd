extends Node3D

@export_group("Properties")
@export var target: Vehicle


# Functions

func _physics_process(delta):
	
	# Set position and rotation to targets
	
	self.position = self.position.lerp(target.get_vehicle_pos(), delta * 4)
