class_name WorldSimulation
extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const W = 128
const H = 64
const CELL = 0.65
const DAY = 480
var seed_value = 24017
var tick = 0
var paused = false
var sandbox = true
var energy = 100.0
var grain = 72.0
var wood = 95.0
var knowledge = 0.0
var era = 0
var relation = 20
var treaty = false
var evacuated = false
var traded = false
var storm_done = false
var flood = 0.0
var heat = 0.0
var temperature = 18.0
var wind = 1
var next_id = 100
var possessed = -1
var inspected = false
var ordered = false
var harvests = 0
var active_faction = 0
var policy = "Balanced"
var cells: Array = []
var people: Array = []
var buildings: Array = []
var events: Array = []
var commands: Array = []
var reservations: Dictionary = {}
var weather_rng = RandomNumberGenerator.new()
var citizen_rng = RandomNumberGenerator.new()
var faction_rng = RandomNumberGenerator.new()
var weather = "Clear skies"
var outcome = ""
var climate_history: Array = []
var supplied_ticks = 0

func setup(world_seed: int = 24017) -> void:
 seed_value = world_seed
 weather_rng.seed = world_seed + 11
 citizen_rng.seed = world_seed + 23
 faction_rng.seed = world_seed + 37
 cells.clear()
 for z in H:
  for x in W:
   var p = position(z * W + x)
   var river = sin(p.y * 0.14) * 3.5 + 7.0
   var distance = abs(p.x-river)
   var elevation = 0.3 + 0.13 * sin(p.x * 0.24) * cos(p.y * 0.22)
   elevation += maxf(0.0, -p.x - 13.0) * 0.13 + maxf(0.0, abs(p.y) - 12.0) * 0.12
   if distance < 2.0: elevation = -0.6 + distance * 0.25
   var noise = sin(float(x*73+z*151+world_seed)) * 0.5 + 0.5
   cells.append({"id":z*W+x, "e":elevation, "water":maxf(0,-elevation), "forest":distance>3.0 and noise>0.68, "fire":0.0, "shield":0, "ice":z<2 or z>=H-2})
 var names = ["Amara", "Rowan", "Isha", "Elian", "Nia", "Tomas", "Sora", "Kael", "Mira", "Oren", "Luna", "Ash"]
 for i in 12:
  add_person(names[i], -8.0 + (i%4)*1.5, -2.0+(i/4)*1.8)
 add_building("home",-8,-4,true)
 add_building("home",-4,-4,true)
 add_building("home",-10,1,true)
 add_building("farm",-4,5,true)
 add_building("well",-5,0,true)
 add_building("home",-20,-5,true)
 for i in people.size(): people[i].home=buildings[i%3].id
 record("A world in your hands", "Twelve settlers arrive in Riverhaven. A refuge waits on the western ridge.",-6,0)

func position(id: int) -> Vector2:
 return Vector2((id%W-W/2)*CELL,(id/W-H/2)*CELL)
func cell_at(x: float,z: float) -> int:
 return clampi(int(round(z/CELL))+H/2,0,H-1)*W+posmod(int(round(x/CELL))+W/2,W)
func elevation(x: float,z: float) -> float:
 return float(cells[cell_at(x,z)].e)
func add_person(n: String,x: float,z: float) -> Dictionary:
 var p = {"id":next_id,"name":n,"x":x,"z":z,"health":100.0,"hunger":5.0,"fatigue":5.0,"age":22.0,"job":"Farmer" if people.size()%3==0 else "Builder" if people.size()%3==1 else "Hauler","task":"idle","target":[x,z],"queue":[],"cargo":0,"alive":true,"faction":active_faction,"blocked":"","path":[],"home":0}
 next_id+=1
 people.append(p)
 return p
func person(id: int) -> Dictionary:
 for p in people:
  if p.id==id: return p
 return {}
func add_building(kind: String,x: float,z: float,complete: bool=false) -> Dictionary:
 var b = {"id":next_id,"kind":kind,"x":x,"z":z,"work":float(Rules.BUILDINGS[kind].work) if complete else 0.0,"complete":complete,"health":100.0}
 next_id+=1
 buildings.append(b)
 return b
func record(title: String,detail: String,x: float=0,z: float=0) -> void:
 events.push_front({"tick":tick,"title":title,"detail":detail,"x":x,"z":z})
 if events.size()>100: events.pop_back()
func alive_count() -> int:
 var count = 0
 for p in people:
  if p.alive: count+=1
 return count
func has_building(kind: String) -> bool:
 for b in buildings:
  if b.kind==kind and b.complete and b.health>0: return true
 return false
func is_safe(x: float,z: float) -> bool:
 var c = cells[cell_at(x,z)]
 return not c.ice and c.e > -0.1 and (c.e > flood or c.shield>tick)
func pathfind(start: int,goal: int) -> Array:
 if start==goal: return []
 var frontier: Array = [start]
 var previous = {start:-1}
 var cursor = 0
 while cursor<frontier.size():
  var here: int = frontier[cursor]
  cursor+=1
  if here==goal: break
  for n in [here/W*W+posmod(here%W+1,W),here/W*W+posmod(here%W-1,W),here-W,here+W]:
   if n<0 or n>=W*H or previous.has(n): continue
   var c = cells[n]
   if c.ice or c.e< -0.1 or (c.e<flood and c.shield<=tick): continue
   previous[n]=here
   frontier.append(n)
 if not previous.has(goal): return []
 var route: Array = []
 var current = goal
 while current!=start:
  route.push_front(current)
  current=previous[current]
 return route
func release_cargo(p: Dictionary) -> void:
 # Cargo always returns exactly once when an order is interrupted.
 grain+=p.cargo
 p.cargo=0
 reservations.erase(str(p.id))
func order(id: int,task: String,x: float,z: float,append: bool=false) -> String:
 var p = person(id)
 if p.is_empty(): return "Select a person first."
 if not p.alive: return "This person has died. Use Resurrection."
 if not task in ["move","gather","build","rest","fight","rescue","idle"]: return "Unsupported order."
 if task!="idle" and not is_safe(x,z):
  p.blocked="The destination is flooded, frozen, or underwater. Raise the ground or choose a safe route."
  return p.blocked
 var route = pathfind(cell_at(p.x,p.z),cell_at(x,z)) if task!="idle" else []
 if task!="idle" and route.is_empty() and cell_at(p.x,p.z)!=cell_at(x,z):
  p.blocked="No dry route. Build a levee, reshape the riverbank, or lift this person."
  return p.blocked
 if append:
  p.queue.append({"task":task,"x":x,"z":z})
  return "Order queued."
 if possessed==id: release()
 release_cargo(p)
 p.task=task
 p.target=[x,z]
 p.path=route
 p.blocked=""
 ordered=true
 commands.append({"tick":tick,"actor":id,"action":task,"x":x,"z":z})
 return "%s: %s" % [p.name,task]
func possess(id: int) -> String:
 var p=person(id)
 if p.is_empty() or not p.alive: return "Choose a living settler."
 if possessed>=0: release()
 release_cargo(p)
 p.task="possessed"
 p.path=[]
 possessed=id
 return "You are %s. Drag the world or use the movement pad; Release restores autonomy." % p.name
func release() -> void:
 var p=person(possessed)
 if not p.is_empty(): p.task="idle"
 possessed=-1
func manual_move(dx: float,dz: float) -> void:
 if paused: return
 var p=person(possessed)
 if p.is_empty(): return
 var x=wrapf(p.x+dx,-W*CELL/2,W*CELL/2)
 var z=clampf(p.z+dz,-H*CELL/2+CELL,H*CELL/2-CELL*2)
 if is_safe(x,z):
  p.x=x
  p.z=z
func place(kind: String,x: float,z: float) -> String:
 if not Rules.BUILDINGS.has(kind): return "Unknown building."
 if Rules.BUILDINGS[kind].era>era: return "Research the next era first."
 if not is_safe(x,z): return "Buildings need dry ground. Raise earth or choose higher terrain."
 for b in buildings:
  if Vector2(b.x-x,b.z-z).length()<1.8: return "Another building occupies this site."
 if wood<Rules.BUILDINGS[kind].wood: return "Not enough timber. Order settlers to gather."
 wood-=Rules.BUILDINGS[kind].wood
 add_building(kind,x,z)
 record("Foundation laid",Rules.BUILDINGS[kind].title+" is ready for a construction crew.",x,z)
 for p in people:
  if p.alive and p.id!=possessed and p.job=="Builder": order(p.id,"build",x,z)
 return "Construction ordered. Timber reserved; builders are on their way."
func cancel_building(id: int) -> String:
 for b in buildings:
  if b.id==id and not b.complete:
   wood+=Rules.BUILDINGS[b.kind].wood
   buildings.erase(b)
   for p in people:
    if p.task=="build" and Vector2(p.target[0]-b.x,p.target[1]-b.z).length()<1: order(p.id,"idle",p.x,p.z)
   return "Construction cancelled; reserved timber returned."
 return "Only unfinished construction can be cancelled."
func power(kind: String,x: float,z: float,override: bool=false) -> String:
 if not Rules.POWERS.has(kind): return "Unknown power."
 var rule=Rules.POWERS[kind]
 if kind in ["fire","lightning","quake","lower"] and not override: return "Confirm this destructive miracle in the preview."
 if not sandbox and energy<rule.cost: return "Not enough faith. Faith recovers even after extinction."
 if not sandbox: energy-=rule.cost
 var affected=0
 for c in cells:
  var pos=position(c.id)
  if pos.distance_to(Vector2(x,z))>rule.radius: continue
  affected+=1
  match kind:
   "rain": c.fire=0.0; c.water+=0.12
   "forest": c.forest=true; c.fire=0.0
   "raise": c.e+=0.8
   "lower": c.e-=0.8
   "fire": c.fire=18.0
   "shield": c.shield=tick+240
   "quake": c.e+=weather_rng.randf_range(-0.35,0.35)
 if kind=="rain": weather="Divine rainfall"; flood=minf(0.65,flood+0.025)
 if kind=="cool": heat-=0.35; temperature-=2
 if kind=="wind": wind=-wind
 if kind=="spawn": add_person("Aster %d" % next_id,x,z)
 for p in people:
  if Vector2(p.x-x,p.z-z).length()>rule.radius: continue
  match kind:
   "heal": p.health=100.0; p.hunger=0.0; p.fatigue=0.0
   "lightning": p.health=0.0
   "resurrect":
    if possessed==p.id: release()
    release_cargo(p); p.path=[]; p.queue=[]; p.alive=true; p.health=100.0; p.hunger=0.0; p.task="idle"
 for b in buildings:
  if Vector2(b.x-x,b.z-z).length()<rule.radius and kind in ["quake","lightning"]: b.health=maxf(0,b.health-45)
 commands.append({"tick":tick,"actor":"god","action":kind,"x":x,"z":z})
 record(rule.title,"Your miracle touched %d cells. Every consequence remains in this world."%affected,x,z)
 return rule.title+" manifested."
func lift(id: int,x: float,z: float) -> String:
 var p=person(id)
 if p.is_empty() or not p.alive: return "Choose a living person first."
 if not is_safe(x,z): return "Set them down on dry ground."
 if possessed==id: release()
 release_cargo(p)
 p.x=x; p.z=z; p.path=[]; p.task="idle"
 ordered=true
 record("A hand from the heavens",p.name+" was lifted to safety.",x,z)
 return p.name+" moved by your hand."
func evacuate() -> void:
 evacuated=true
 for p in people:
  if p.alive and p.id!=possessed:
   var result=order(p.id,"rescue",-20.0+float(p.id%3),-2.0+float(p.id%4))
   if result.begins_with("No dry"): p.blocked=result
 record("To the high ground","Riverhaven has been ordered to evacuate to the western refuge.",-20,-2)
func diplomacy(action: String) -> String:
 match action:
  "trade":
   if wood<20: return "The camp asks for 20 timber."
   wood-=20; grain+=55; relation+=25; traded=true
   record("The cedar pact","20 timber exchanged for 55 grain and flood-rescue boats. Camp aid reduces exposure during the storm.",18,-8)
  "treaty":
   if relation<30: return "Trust is too low. Trade or offer tribute first."
   treaty=true; relation+=10
   record("A lasting peace","The camp has accepted a truce. Raids are suspended.",18,-8)
  "tribute":
   if grain<15: return "Tribute requires 15 grain."
   grain-=15; relation+=20
  "threaten": relation-=35
 return "Camp relations: %d. %s"%[relation,"Truce active." if treaty else "No treaty."]
func research() -> String:
 var requirement=era_requirement()
 if not requirement.is_empty(): return requirement
 if era<3:
  era+=1; knowledge=0
  record("A new age",Rules.ERAS[era]+" dawns. New structures are available.")
 return "Your civilization enters "+Rules.ERAS[era]+"."
func era_requirement() -> String:
 match era:
  0:
   if harvests<1: return "Harvest grain from a working farm."
   if not has_building("storehouse"): return "Complete a storehouse."
  1:
   if not has_building("market"): return "Complete a caravan market."
   if not has_building("workshop"): return "Complete a workshop."
   if not traded: return "Establish a timber-for-grain trade."
  2:
   if not has_building("windmill"): return "Complete a wind generator."
   if knowledge<80: return "Research needs %d more knowledge."%ceili(80-knowledge)
  3: return "Build the observatory; supply two settlements for a year."
 return ""
func step() -> void:
 if paused: return
 tick+=1
 energy=minf(100,energy+0.035)
 var day=tick/DAY+1
 if tick==DAY: weather="Upstream storm forecast"; record("Storm watch","Heavy rain upstream. Evacuate, secure a trade, or raise the riverbank before day three.",7,-10)
 if tick==DAY*2: weather="River in flood"; record("The river rises","The low road is submerged. Keep eight settlers alive and restore a working food route.",7,0)
 if tick>=DAY*2 and tick<DAY*3: flood=minf(0.62,flood+0.003)
 elif tick>=DAY*3: flood=maxf(0.0,flood-0.002)
 if tick==DAY*3: weather="Waters receding"; storm_done=true; record("After the storm","Floodwater recedes. Repair and rebuild; the world carries on.")
 var levee=has_building("levee")
 if levee or elevation(4,0)>0.9: flood=minf(flood,0.12)
 for c in cells:
  if c.fire>0:
   c.fire=maxf(0,c.fire-0.15)
   if c.fire>1 and c.forest:
    c.forest=false
    if tick%12==0:
     var n=c.id/W*W+posmod(c.id%W+wind,W)
     if cells[n].forest and cells[n].shield<=tick: cells[n].fire=12.0
 for p in people:
  if not p.alive: continue
  p.age+=1.0/(DAY*40)
  p.hunger+=0.012 if policy!="Rationing" else 0.008
  p.fatigue+=0.008
  var c=cells[cell_at(p.x,p.z)]
  if c.shield<=tick:
   if c.e<flood: p.health-=0.07 if traded else 0.36
   if c.fire>0: p.health-=0.6
  if p.hunger>85: p.health-=0.09
  if p.health<=0:
   p.alive=false; release_cargo(p)
   if possessed==p.id: release()
   record("A life lost",p.name+" died. In sandbox, resurrection can restore them.",p.x,p.z)
   continue
  if p.task=="possessed": continue
  if p.task=="blocked" and storm_done and flood<0.1: p.task="idle"; p.blocked=""
  if not p.path.is_empty():
   var point=position(p.path[0])
   var delta=point-Vector2(p.x,p.z)
   delta.x=wrapf(delta.x,-W*CELL/2,W*CELL/2)
   if not is_safe(point.x,point.y):
    p.path=[]; p.blocked="The route flooded. Lift this person or evacuate by a dry route."; p.task="blocked"; release_cargo(p)
   elif delta.length()<0.18: p.path.pop_front()
   else:
    var direction=delta.normalized()*0.16
    p.x=wrapf(p.x+direction.x,-W*CELL/2,W*CELL/2); p.z+=direction.y
   continue
  match p.task:
   "move": p.task="idle"
   "rescue": p.task="shelter"
   "shelter":
    p.fatigue=maxf(0,p.fatigue-0.1)
    if storm_done and flood<0.1: p.task="idle"
   "fight": p.blocked="Defending this position against camp raids."
   "rest": p.fatigue=maxf(0,p.fatigue-0.5); p.health=minf(100,p.health+0.05); p.task="idle" if p.fatigue<=0 else "rest"
   "gather":
    wood+=0.09
    if tick%80==0: p.task="idle"
   "harvest":
    if tick%60==0:
     p.cargo=2; reservations[str(p.id)]="harvest"; harvests+=1
     p.task="deliver"; p.target=[-7.0,0.0]; p.path=pathfind(cell_at(p.x,p.z),cell_at(-7,0))
     if p.path.is_empty() and cell_at(p.x,p.z)!=cell_at(-7,0):
      release_cargo(p); p.blocked="The food route is flooded."; p.task="blocked"
   "deliver":
    grain+=p.cargo; p.cargo=0; reservations.erase(str(p.id)); p.task="idle"
   "build":
    var worked=false
    for b in buildings:
     if not b.complete and Vector2(b.x-p.x,b.z-p.z).length()<2.0:
      worked=true; b.work+=0.7
      if b.work>=Rules.BUILDINGS[b.kind].work:
       b.complete=true; record("Built to endure",Rules.BUILDINGS[b.kind].title+" is complete.",b.x,b.z)
    if not worked: p.task="idle"
  if p.task=="idle":
   if not p.queue.is_empty():
    var q=p.queue.pop_front(); order(p.id,q.task,q.x,q.z); continue
   if p.hunger>12 and grain>=1:
    grain-=1; p.hunger=maxf(0,p.hunger-16)
   if p.fatigue>65: p.task="rest"
   elif p.job=="Farmer" and has_building("farm") and is_safe(-4,5):
    p.task="harvest"; p.target=[-4.0,5.0]; p.path=pathfind(cell_at(p.x,p.z),cell_at(-4,5))
    if p.path.is_empty() and cell_at(p.x,p.z)!=cell_at(-4,5): p.blocked="The food route is flooded."; p.task="blocked"
   elif p.job=="Builder":
    for b in buildings:
     if not b.complete: order(p.id,"build",b.x,b.z); break
   else: p.task="gather"
 if tick%30==0:
  knowledge+=1.0+(2.0 if has_building("workshop") else 0)
  if not treaty and relation<0 and faction_rng.randf()<0.2:
   var defenders=0
   for guard in people:
    if guard.alive and guard.task=="fight": defenders+=1
   if defenders>=2: record("Raid repelled","Your defenders protected the stores. The camp retreats.",18,-8)
   else: grain=maxf(0,grain-12); record("Raid on the stores","The camp took 12 grain. Post two defenders or negotiate a truce.",18,-8)
 if tick%(DAY*10)==0:
  var forests=0
  for c in cells:
   if c.forest: forests+=1
  heat+=(0.08 if era>=2 else 0.01)-float(forests)*0.00002-(0.06 if has_building("windmill") else 0)
  climate_history.append(heat)
 temperature=18+sin(float(tick)/float(DAY*40)*TAU)*8+heat
 if tick>=DAY*3+120 and outcome.is_empty():
  if alive_count()>=8 and food_route_working() and grain>0:
   outcome="River Test complete"; record(outcome,"At least eight people survived with a restored food supply. Continue building your civilization.")
  elif alive_count()<8:
   outcome="A recoverable world"; record(outcome,"Fewer than eight survived. Continue in sandbox, restore lives, or begin the same seed again.")
 var supplied=grain>20 and food_route_working() and alive_count()>=8
 if supplied:
  var store={}
  for b in buildings:
   if b.kind=="storehouse" and b.complete: store=b; break
  supplied=not store.is_empty() and is_safe(-20,-5) and not pathfind(cell_at(store.get("x",0),store.get("z",0)),cell_at(-20,-5)).is_empty()
 supplied_ticks=supplied_ticks+1 if supplied else 0
 if has_building("observatory") and supplied_ticks>=DAY*40:
  if outcome!="Stewardship complete": outcome="Stewardship complete"; record(outcome,"The observatory watches over Riverhaven and the refuge after a full uninterrupted year of food-route access.")
func food_route_working() -> bool:
 if traded: return true
 if not has_building("storehouse") or not has_building("farm") or not is_safe(-4,5): return false
 for b in buildings:
  if b.kind!="storehouse" or not b.complete or not is_safe(b.x,b.z): continue
  if pathfind(cell_at(-4,5),cell_at(b.x,b.z)).is_empty(): continue
  for p in people:
   if p.alive and p.job=="Farmer" and is_safe(p.x,p.z): return true
 return false
func objectives() -> Array:
 return [inspected,ordered,has_building("storehouse"),storm_done and alive_count()>=8,not outcome.is_empty() and outcome=="River Test complete"]
func snapshot() -> Dictionary:
 return {"version":1,"seed":seed_value,"tick":tick,"paused":paused,"sandbox":sandbox,"energy":energy,"grain":grain,"wood":wood,"knowledge":knowledge,"era":era,"relation":relation,"treaty":treaty,"evacuated":evacuated,"traded":traded,"storm_done":storm_done,"flood":flood,"heat":heat,"temperature":temperature,"wind":wind,"next_id":next_id,"possessed":possessed,"inspected":inspected,"ordered":ordered,"harvests":harvests,"active_faction":active_faction,"policy":policy,"cells":cells,"people":people,"buildings":buildings,"events":events,"commands":commands,"reservations":reservations,"weather":weather,"outcome":outcome,"climate_history":climate_history,"supplied_ticks":supplied_ticks,"rng":[str(weather_rng.state),str(citizen_rng.state),str(faction_rng.state)]}
func finite_fields(data: Dictionary,keys: Array) -> bool:
 for key in keys:
  if not data.has(key) or not (data[key] is int or data[key] is float) or not is_finite(float(data[key])): return false
 return true
func valid_state(data: Dictionary) -> bool:
 if data.get("version")!=1 or not data.get("cells") is Array or data.cells.size()!=W*H: return false
 if not data.get("rng") is Array or data.rng.size()!=3: return false
 for value in data.rng:
  if not value is String or not value.is_valid_int(): return false
 var schema=snapshot()
 for key in schema:
  if not data.has(key): return false
  var expected=schema[key]
  if expected is float or expected is int:
   if not (data[key] is float or data[key] is int) or not is_finite(float(data[key])): return false
  elif typeof(data[key])!=typeof(expected): return false
 if data.era<0 or data.era>3 or data.tick<0 or data.people.size()>5000: return false
 var expected_id=0
 for c in data.cells:
  if not c is Dictionary or not c.has_all(["id","e","water","forest","fire","shield","ice"]): return false
  if not c.id is int or c.id!=expected_id: return false
  expected_id+=1
  if not c.forest is bool or not c.ice is bool: return false
  for key in ["e","water","fire","shield"]:
   if not (c[key] is float or c[key] is int) or not is_finite(float(c[key])): return false
 var ids={}
 for p in data.people:
  if not p is Dictionary or not p.has_all(["id","name","x","z","health","hunger","fatigue","age","job","task","target","queue","cargo","alive","faction","blocked","path","home"]): return false
  if not p.id is int or ids.has(p.id) or not p.name is String or not p.task is String or not p.job is String or not p.blocked is String: return false
  ids[p.id]=true
  if not p.path is Array or not p.queue is Array or not p.target is Array or p.target.size()!=2: return false
  for waypoint in p.path:
   if not waypoint is int or waypoint<0 or waypoint>=W*H: return false
  for queued in p.queue:
   if not queued is Dictionary or not queued.has_all(["task","x","z"]): return false
   if not queued.task is String or not queued.task in ["move","gather","build","rest","fight","rescue","idle"] or not finite_fields(queued,["x","z"]): return false
  if not p.alive is bool: return false
  for value in p.target:
   if not (value is int or value is float) or not is_finite(float(value)): return false
  for key in ["x","z","health","hunger","fatigue","age","cargo","faction","home"]:
   if not (p[key] is float or p[key] is int) or not is_finite(float(p[key])): return false
 for b in data.buildings:
  if not b is Dictionary or not b.has_all(["id","kind","x","z","work","complete","health"]): return false
  if not b.kind is String or not Rules.BUILDINGS.has(b.kind) or not b.complete is bool or not b.id is int or ids.has(b.id): return false
  ids[b.id]=true
  if not finite_fields(b,["x","z","work","health"]): return false
 for e in data.events:
  if not e is Dictionary or not e.has_all(["tick","title","detail","x","z"]): return false
  if not e.title is String or not e.detail is String or not finite_fields(e,["tick","x","z"]): return false
 return true
func restore(data: Dictionary) -> bool:
 # Validate everything before touching the live simulation.
 if not valid_state(data): return false
 var integers=["seed_value","tick","era","relation","wind","next_id","possessed","harvests","active_faction","supplied_ticks"]
 for key in snapshot():
  if key in ["version","seed","rng"]: continue
  if not data.has(key): return false
 for key in snapshot():
  if key in ["version","seed","rng"]: continue
  if key in integers: set(key,int(data[key]))
  else: set(key,data[key])
 seed_value=int(data.seed)
 for p in people:
  p.id=int(p.id); p.home=int(p.home); p.faction=int(p.faction)
  for i in p.path.size(): p.path[i]=int(p.path[i])
 for c in cells: c.id=int(c.id); c.shield=int(c.shield)
 for b in buildings: b.id=int(b.id)
 weather_rng.state=int(data.rng[0]); citizen_rng.state=int(data.rng[1]); faction_rng.state=int(data.rng[2])
 return true
func state_hash() -> String:
 return JSON.stringify(snapshot(),"",true,true).sha256_text()
func save_world(path: String="user://worldkeeper.json") -> bool:
 var state=snapshot()
 var payload=Marshalls.raw_to_base64(var_to_bytes(state))
 var content=JSON.stringify({"version":1,"encoding":"godot-variant-base64","state":payload})
 var test=WorldSimulation.new()
 if not test.restore(bytes_to_var(Marshalls.base64_to_raw(payload))): return false
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null: return false
 file.store_string(content); file.close()
 var absolute=ProjectSettings.globalize_path(path)
 if FileAccess.file_exists(path):
  if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(absolute+".bak")
  DirAccess.rename_absolute(absolute,absolute+".bak")
 return DirAccess.rename_absolute(absolute+".tmp",absolute)==OK
func load_world(path: String="user://worldkeeper.json") -> bool:
 for candidate in [path,path+".bak"]:
  if not FileAccess.file_exists(candidate): continue
  var parser=JSON.new()
  if parser.parse(FileAccess.get_file_as_string(candidate))!=OK: continue
  var envelope=parser.data
  if not envelope is Dictionary or envelope.get("version")!=1 or envelope.get("encoding")!="godot-variant-base64" or not envelope.get("state") is String: continue
  var data=bytes_to_var(Marshalls.base64_to_raw(envelope.state))
  if data is Dictionary and restore(data): return true
 return false
