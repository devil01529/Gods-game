extends SceneTree
const Simulation = preload("res://scripts/simulation.gd")
var failures = 0
var checks = 0
func check(condition: bool,message: String) -> void:
 checks+=1
 if not condition: failures+=1; push_error("FAIL: "+message)
 else: print("PASS: "+message)
func advance(s: WorldSimulation,count: int) -> void:
 for i in count: s.step()
func fresh() -> WorldSimulation:
 var s=Simulation.new(); s.setup(); return s
func _initialize() -> void:
 var s=fresh(); var duplicate=fresh()
 check(s.state_hash()==duplicate.state_hash(),"same seed yields identical initial world")
 s.paused=true; advance(s,12); check(s.tick==0,"pause advances exactly zero ticks")
 s.paused=false; s.step(); s.paused=true; check(s.tick==1,"single step advances exactly one tick")
 var route=s.pathfind(s.cell_at(-40,0),s.cell_at(40,0))
 check(route.size()>0 and route.size()<10,"east-west seam uses the short route")
 var north=s.cell_at(0,-Simulation.H*Simulation.CELL/2)
 check(s.cells[north].ice,"poles are impassable ice caps")
 s=fresh(); var p=s.people[0]; p.cargo=3; s.grain-=3; s.reservations[str(p.id)]="test"
 var total=s.grain+p.cargo
 s.possess(p.id); s.release(); s.order(p.id,"move",-9,2)
 check(s.grain+p.cargo==total and s.reservations.is_empty(),"possession and interrupted delivery conserve cargo exactly once")
 check(s.order(p.id,"move",7,0).contains("flooded"),"underwater destination returns a reason")
 check(s.order(p.id,"unsupported",0,0)=="Unsupported order.","unsupported tasks are rejected")
 s.order(p.id,"move",-8,1); s.order(p.id,"rest",-8,1,true)
 check(p.queue.size()==1,"explicit task queue is retained")
 var wood=s.wood
 s.place("storehouse",-2,-2)
 var b=s.buildings.back()
 check(s.wood==wood-18,"construction reserves materials once")
 s.cancel_building(b.id)
 check(s.wood==wood,"cancelled foundation returns reserved materials")
 var health=p.health
 check(s.power("lightning",p.x,p.z).begins_with("Confirm") and p.health==health,"destructive power requires an explicit visible override")
 s.power("lightning",p.x,p.z,true); s.step()
 check(not p.alive,"lightning has a real life-or-death consequence")
 s.power("resurrect",p.x,p.z,true)
 check(p.alive and p.health==100,"sandbox resurrection restores a dead person")
 s.sandbox=false; s.energy=0; check(s.power("rain",0,0).contains("Not enough"),"challenge rejects powers without energy")
 s.step(); check(s.energy>0,"faith regenerates from baseline")
 s=fresh(); s.place("storehouse",-2,-2); advance(s,400)
 check(s.has_building("storehouse"),"builders travel to and finish a storehouse")
 check(s.harvests>0 and s.grain>0,"farmers harvest and physically deliver food")
 check(s.research().contains("SETTLEMENT"),"demonstrated harvest and storehouse unlock settlement era")
 var paused_hash=s.state_hash(); s.save_world("user://regression.json")
 var loaded=Simulation.new()
 check(loaded.load_world("user://regression.json"),"versioned save loads")
 check(s.state_hash()==loaded.state_hash(),"save/load preserves complete state hash")
 advance(s,610); advance(loaded,610)
 check(s.state_hash()==loaded.state_hash(),"mid-flood resumed simulation matches uninterrupted run")
 s.save_world("user://regression.json"); s.save_world("user://regression.json")
 var broken=FileAccess.open("user://regression.json",FileAccess.WRITE); broken.store_string("{broken"); broken.close()
 var recovery=Simulation.new(); check(recovery.load_world("user://regression.json"),"corrupt primary save recovers previous good backup")
 s=fresh(); s.diplomacy("trade"); s.diplomacy("treaty"); s.save_world("user://treaty.json")
 loaded=Simulation.new(); loaded.load_world("user://treaty.json")
 check(loaded.treaty and loaded.relation==s.relation,"ceasefire survives save/load")
 s=fresh(); p=s.people[0]; s.possess(p.id); s.order(p.id,"move",-9,2)
 check(s.possessed==-1 and p.task=="move","direct order explicitly releases possession")
 s=fresh(); p=s.people[0]; p.x=40; p.z=0; p.job="Hauler"; s.order(p.id,"move",-40,0); advance(s,40)
 check(abs(p.x+40)<1,"movement follows the short wrapped seam route")
 s=fresh(); s.evacuate(); advance(s,1300)
 var shelter_count=0
 for resident in s.people:
  if resident.alive and resident.task=="shelter": shelter_count+=1
 check(shelter_count==12,"evacuated residents hold at safe refuge through the storm")
 s=fresh(); p=s.people[0]; s.possess(p.id); s.lift(p.id,-20,-2)
 check(s.possessed==-1 and p.task=="idle","lifting a possessed person clears possession")
 var before=s.state_hash(); var invalid=s.snapshot().duplicate(true); invalid.tick=12345; invalid.rng=[]
 check(not s.restore(invalid) and s.state_hash()==before,"malformed restore leaves live world untouched")
 invalid=s.snapshot().duplicate(true); invalid.people[0].path=[-500]
 check(not s.restore(invalid) and s.state_hash()==before,"malformed nested waypoint is rejected atomically")
 invalid=s.snapshot().duplicate(true); invalid.buildings[0].x="broken"
 check(not s.restore(invalid) and s.state_hash()==before,"malformed building coordinates are rejected atomically")
 invalid=s.snapshot().duplicate(true); invalid.people[0].queue=[{"task":{},"x":"oops","z":0}]
 check(not s.restore(invalid) and s.state_hash()==before,"malformed queued commands are rejected atomically")
 var results=[]
 for solution in ["ignore","evacuate","trade","levee"]:
  var run=fresh(); run.place("storehouse",-2,-2); advance(run,500)
  if solution=="evacuate": run.evacuate()
  elif solution=="trade":
   run.diplomacy("trade")
  elif solution=="levee": run.place("levee",3,0)
  advance(run,1400)
  var result={"solution":solution,"survivors":run.alive_count(),"grain":int(run.grain),"outcome":run.outcome}
  results.append(result); print("SCENARIO: "+JSON.stringify(result))
 check(results[0].survivors<8,"ignoring the storm produces materially worse survival")
 for i in range(1,4): check(results[i].survivors>=8 and results[i].outcome=="River Test complete","River Test succeeds by "+results[i].solution)
 print("RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures>0 else 0)
