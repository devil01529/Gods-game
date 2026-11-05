extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.sim.reproduction="Paused";game.sim.power("quake",-6,0,true);game.world.sync()
 assert(game.world.get_node("PlanetCollision")!=null)
 assert(game.world.rigid_debris.size()>0)
 var body=game.world.rigid_debris[0];var initial_velocity=body.linear_velocity.dot(body.position.normalized())
 for i in 15:await physics_frame
 assert(body.linear_velocity.dot(body.position.normalized())<initial_velocity)
 for i in 120:await physics_frame
 for rock in game.world.rigid_debris:assert(rock.position.length()>WorldSimulation.PLANET_RADIUS-.1)
 game.sim.paused=true;game.world.animate(0)
 var position_before=body.position
 for i in 5:await physics_frame
 assert(body.position.distance_to(position_before)<.001)
 print("PHYSICS_PASS: radial gravity, spherical terrain collision, real rigid debris, pause freeze")
 quit()
