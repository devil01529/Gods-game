class_name WorldSimulation
extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const W = 256
const H = 128
const CELL = 1.0
const RADIUS = W * CELL / TAU
const PLANET_RADIUS = 82.0
const DT = 0.1
const DAY = 4800
const VERSION = 2
var seed_value = 24017
var tick = 0
var paused = false
var sandbox = true
var energy = 100.0
var grain = 90.0
var wood = 120.0
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
var reproduction = "Natural"
var births = 0
var cells: Array = []
var people: Array = []
var buildings: Array = []
var animals: Array = []
var disasters: Array = []
var events: Array = []
var commands: Array = []
var reservations: Dictionary = {}
var active_cells: Dictionary = {}
var solid_cells: Dictionary = {}
var weather_rng = RandomNumberGenerator.new()
var citizen_rng = RandomNumberGenerator.new()
var faction_rng = RandomNumberGenerator.new()
var weather = "Clear skies"
var outcome = ""
var climate_history: Array = []
var supplied_ticks = 0
var terrain_revision = 0
var ecology_revision = 0

func setup(world_seed: int=24017) -> void:
 seed_value=world_seed
 weather_rng.seed=world_seed+11; citizen_rng.seed=world_seed+23; faction_rng.seed=world_seed+37
 var noise=FastNoiseLite.new(); noise.seed=world_seed; noise.frequency=0.055; noise.fractal_octaves=4
 cells.clear()
 for z in H:
  for x in W:
   var id=z*W+x; var p=position(id)
   var lon=p.x/RADIUS; var lat=p.y/RADIUS
   var dir=Vector3(cos(lat)*sin(lon),sin(lat),cos(lat)*cos(lon))
   var h=noise.get_noise_3dv(dir*90.0)*6.5-0.45
   var local=1.0-smoothstep(23.0,36.0,p.length())
   var valley=0.40+0.09*sin(p.x*.23)*cos(p.y*.21)
   valley+=maxf(0.0,-p.x-15)*0.18
   h=lerpf(h,valley,local)
   var river=sin(p.y*.14)*3.5+7.0
   if abs(p.x-river)<1.6 and abs(p.y)<27: h=-0.65+abs(p.x-river)*0.24
   var polar=z<3 or z>=H-3
   if polar:h=maxf(h,0.35)
   var forest=h>0.15 and not polar and sin(float(id*73+world_seed))>0.18
   cells.append({"id":id,"e":h,"water":maxf(0,-h),"moisture":0.08,"forest":forest,"fuel":8.0 if forest else 1.5,"fire":0.0,"burn":0.0,"electric":0,"shield":0,"ice":polar,"ash":0.0,"dry_until":0})
 var names=["Amara","Rowan","Isha","Elian","Nia","Tomas","Sora","Kael","Mira","Oren","Luna","Ash"]
 for i in 12: add_person(names[i],-8.0+(i%4)*1.5,-2.0+(i/4)*1.8)
 add_building("home",-8,-5,true); add_building("home",-3,-5,true); add_building("home",-11,1,true)
 add_building("farm",-3,5,true); add_building("well",-5,0,true); add_building("home",-20,-5,true)
 for i in people.size(): people[i].home=buildings[i%3].id
 add_animal("dog",-7,1,people[0].id); add_animal("cat",-5,-3,people[1].id)
 for i in 6: add_animal("deer",-17+i*1.1,9+i%3,-1)
 record("The living planet","A whole world, twelve lives, and every decision in your hands.",-6,0)
func position(id: int) -> Vector2:
 return Vector2((id%W-W/2)*CELL,(id/W-H/2)*CELL)
func cell_at(x: float,z: float) -> int:
 return clampi(int(round(z/CELL))+H/2,0,H-1)*W+posmod(int(round(x/CELL))+W/2,W)
func elevation(x: float,z: float) -> float: return float(cells[cell_at(x,z)].e)
func normal_at(x: float,z: float) -> Vector3:
 var lon=x/RADIUS; var lat=z/RADIUS
 return Vector3(cos(lat)*sin(lon),sin(lat),cos(lat)*cos(lon))
func surface(x: float,z: float,offset: float=0.0) -> Vector3:
 return normal_at(x,z)*(PLANET_RADIUS+elevation(x,z)+offset)
func wrapped_delta(a: Vector2,b: Vector2) -> Vector2:
 return Vector2(wrapf(b.x-a.x,-W*CELL/2,W*CELL/2),b.y-a.y)
func distance(a: Vector2,b: Vector2) -> float: return wrapped_delta(a,b).length()
func neighbors(id: int) -> Array:
 var out=[id/W*W+posmod(id%W+1,W),id/W*W+posmod(id%W-1,W)]
 if id>=W:out.append(id-W)
 if id<W*(H-1):out.append(id+W)
 return out
func add_person(n: String,x: float,z: float,age: float=22.0,parents: Array=[]) -> Dictionary:
 var p={"id":next_id,"name":n,"x":x,"z":z,"health":100.0,"hunger":5.0,"fatigue":5.0,"age":age,"job":"Child" if age<16 else ["Farmer","Builder","Hauler"][people.size()%3],"task":"idle","authority":"Auto","target":[x,z],"queue":[],"cargo":0.0,"alive":true,"faction":active_faction,"blocked":"","path":[],"home":0,"work":0.0,"target_id":-1,"sex":"F" if people.size()%2==0 else "M","partner":-1,"pregnancy":0,"parents":parents,"birth_tick":tick,"last_birth":-DAY*10,"blocked_task":""}
 next_id+=1; people.append(p); return p
func person(id: int) -> Dictionary:
 for p in people:
  if p.id==id:return p
 return {}
func add_building(kind: String,x: float,z: float,complete: bool=false) -> Dictionary:
 var b={"id":next_id,"kind":kind,"x":x,"z":z,"work":float(Rules.BUILDINGS[kind].work) if complete else 0.0,"complete":complete,"health":100.0}
 next_id+=1; buildings.append(b)
 if kind in ["home","storehouse","market","workshop","windmill","observatory"]:solid_cells[cell_at(x,z)]=b.id
 return b
func add_animal(species: String,x: float,z: float,owner: int=-1) -> Dictionary:
 var names={"dog":"Cedar","cat":"Clover","deer":"Wild deer"}
 var a={"id":next_id,"name":names[species]+(" %d"%next_id if species=="deer" else ""),"species":species,"x":x,"z":z,"health":100.0,"hunger":5.0,"alive":true,"owner":owner,"mode":"Follow" if owner>=0 else "Roam","target":[x,z],"wait":0}
 next_id+=1; animals.append(a); return a
func record(title: String,detail: String,x: float=0,z: float=0) -> void:
 events.push_front({"tick":tick,"title":title,"detail":detail,"x":x,"z":z})
 if events.size()>100:events.pop_back()
func alive_count() -> int:
 var count=0
 for p in people:
  if p.alive:count+=1
 return count
func has_building(kind: String) -> bool:
 for b in buildings:
  if b.kind==kind and b.complete and b.health>0:return true
 return false
func is_safe(x: float,z: float) -> bool:
 var c=cells[cell_at(x,z)]
 return not c.ice and c.e> -0.08 and c.water<0.5
func pathfind(start: int,goal: int,risky: bool=false) -> Array:
 if start==goal:return []
 var open: Array=[start]; var previous={start:-1}; var cursor=0
 while cursor<open.size():
  var here: int=open[cursor];cursor+=1
  if here==goal:break
  for n in neighbors(here):
   if previous.has(n) or solid_cells.has(n):continue
   var c=cells[n]
   if c.ice or c.e< -0.08 or (not risky and (c.water>=0.5 or c.fire>0.1)):continue
   previous[n]=here;open.append(n)
  if cursor>12000:break
 if not previous.has(goal):return []
 var route: Array=[];var current=goal
 while current!=start:route.push_front(current);current=previous[current]
 return route
func release_cargo(p: Dictionary) -> void:
 grain+=p.cargo;p.cargo=0.0;reservations.erase(str(p.id))
func _set_route(p: Dictionary,task: String,x: float,z: float,risky: bool=false) -> bool:
 var start=cell_at(p.x,p.z);var goal=cell_at(x,z);var route=pathfind(start,goal,risky)
 if start!=goal and route.is_empty():p.blocked="No safe route. Use Lift, dry the route, or confirm a dangerous order.";return false
 p.task=task;p.target=[x,z];p.path=route;p.blocked="";p.blocked_task="";p.work=0.0;return true
func order(id: int,task: String,x: float,z: float,append: bool=false,force: bool=false) -> String:
 var p=person(id)
 if p.is_empty():return "Select a person first."
 if not p.alive:return "This person has died. Resurrection can restore them."
 if not task in ["move","gather","build","rest","fight","rescue","idle","hold"]:return "Unsupported order."
 if task not in ["idle","hold"] and not force and not is_safe(x,z):return "The destination is underwater or frozen. Choose dry land, or use Lift."
 var building_id=-1
 if task=="build":
  var found=false
  for b in buildings:
   if not b.complete and b.health>0 and distance(Vector2(x,z),Vector2(b.x,b.z))<2:found=true;building_id=b.id;break
  if not found:return "Place a building foundation first, then order construction there."
  for b in buildings:
   if b.id==building_id:
    var access=access_point(b,p);x=access.x;z=access.y;break
 if append:p.queue.append({"task":task,"x":x,"z":z});return "Order queued."
 if task not in ["idle","hold"]:
  if not _set_route(p,task,x,z,force):return p.blocked
 else:p.task="hold";p.path=[];p.target=[p.x,p.z]
 if building_id>=0:p.target_id=building_id
 if possessed==id:possessed=-1
 release_cargo(p);p.authority="God";p.blocked="";ordered=true
 commands.append({"tick":tick,"actor":id,"action":task,"x":x,"z":z})
 record("Your will, obeyed",p.name+": "+task+". This command remains in force until you release it.",x,z)
 return p.name+": "+task.capitalize()+" ordered."
func resume(id: int) -> void:
 var p=person(id)
 if p.is_empty():return
 if possessed==id:possessed=-1
 release_cargo(p);p.authority="Auto";p.task="idle";p.path=[];p.queue=[];p.blocked=""
func possess(id: int) -> String:
 var p=person(id)
 if p.is_empty() or not p.alive:return "Choose a living person."
 if possessed>=0:release()
 release_cargo(p);p.task="possessed";p.authority="God";p.path=[];possessed=id
 return "Controlling "+p.name+". Use the movement pad; Release restores autonomy."
func release() -> void:
 var id=possessed;possessed=-1
 if id>=0:resume(id)
func manual_move(dx: float,dz: float) -> void:
 if paused:return
 var p=person(possessed)
 if p.is_empty():return
 var x=wrapf(p.x+dx,-W*CELL/2,W*CELL/2);var z=clampf(p.z+dz,-H*CELL/2+2,H*CELL/2-2)
 if is_safe(x,z) and not solid_cells.has(cell_at(x,z)):p.x=x;p.z=z
func place(kind: String,x: float,z: float) -> String:
 if not Rules.BUILDINGS.has(kind):return "Unknown building."
 var rule=Rules.BUILDINGS[kind]
 if rule.era>era:return "Unlock "+Rules.ERAS[rule.era]+" first."
 if not is_safe(x,z):return "Place the foundation on dry land."
 for b in buildings:
  if distance(Vector2(b.x,b.z),Vector2(x,z))<2.8:return "Leave more room between buildings."
 if wood<rule.wood:return "Not enough timber. Send a worker to gather in a forest."
 wood-=rule.wood;add_building(kind,x,z)
 record("Foundation placed",rule.title+". Autonomous builders will bring it to life.",x,z)
 for p in people:
  if p.alive and p.job=="Builder" and p.authority=="Auto":p.task="idle";p.path=[]
 return rule.title+" construction started."
func cancel_building(id: int) -> String:
 for b in buildings:
  if b.id==id and not b.complete:
   wood+=Rules.BUILDINGS[b.kind].wood;solid_cells.erase(cell_at(b.x,b.z));buildings.erase(b)
   for p in people:
    if p.target_id==id:release_cargo(p);p.path=[];p.task="hold" if p.authority=="God" else "idle";p.target_id=-1
   return "Foundation cancelled. Timber returned."
 return "This building cannot be cancelled."
func damage(p: Dictionary,amount: float,cause: String) -> void:
 if not p.alive:return
 p.health=maxf(0,p.health-amount)
 if p.health<=0:
  p.alive=false;release_cargo(p);p.path=[];p.task="dead";p.queue=[]
  if possessed==p.id:possessed=-1
  record("A life lost",p.name+" died from "+cause+". You may resurrect them.",p.x,p.z)
func _activate(id: int) -> void:active_cells[id]=true
func _wet(id: int,amount: float) -> void:
 var c=cells[id];c.water=maxf(maxf(0,-c.e),c.water+amount);c.moisture=minf(1,c.moisture+amount);c.fire=0.0;c.burn=0.0;_activate(id)
func _ignite(id: int,intensity: float=1.0) -> bool:
 var c=cells[id]
 if c.ice or c.water>0.12 or c.moisture>0.65 or c.fuel<=0 or c.shield>tick:return false
 c.fire=maxf(c.fire,intensity);c.burn=0.0;_activate(id);return true
func power(kind: String,x: float,z: float,override: bool=false) -> String:
 if not Rules.POWERS.has(kind):return "Unknown power."
 var r=Rules.POWERS[kind]
 if r.get("danger",false) and not override:return "Confirm this destructive miracle."
 if not sandbox and energy<r.cost:return "Not enough faith."
 if not sandbox:energy-=r.cost
 var touched={};var conductive={};var center=Vector2(x,z);var radius=float(r.radius)
 for dz in range(-ceili(radius),ceili(radius)+1):
  for dx in range(-ceili(radius),ceili(radius)+1):
   var id=cell_at(x+dx,z+dz)
   if distance(position(id),center)>radius:continue
   touched[id]=true;var c=cells[id]
   match kind:
    "rain":_wet(id,.30);c.dry_until=0
    "forest":c.forest=true;c.fuel=8.0;c.ash=0.0;c.moisture=.7;c.fire=0.0
    "raise":c.e+=.7
    "lower":c.e-=.7;_wet(id,maxf(0,-c.e-c.water))
    "fire":_ignite(id)
    "shield":c.shield=tick+2400
    "quake":c.e+=weather_rng.randf_range(-.15,.15);c.ash=.6
    "flood":_wet(id,1.65)
    "drought":c.water=maxf(0,-c.e);c.moisture=0.0;c.dry_until=tick+DAY
    "meteor":c.e-=.8;_ignite(id,1.3);c.ash=1.0
 if kind=="lightning":
  var root=cell_at(x,z);var front=[root];var seen={root:true};var cursor=0
  while cursor<front.size() and cursor<1600:
   var id: int=front[cursor];cursor+=1;var c=cells[id]
   if c.water>.1 or id==root:
    c.electric=tick+20;_activate(id);conductive[id]=true
    if c.water<.1:_ignite(id,.8)
    for n in neighbors(id):
     if not seen.has(n) and cells[n].water>.1 and distance(position(n),center)<12:seen[n]=true;front.append(n)
 if kind=="rain":weather="Rainfall";disasters.append({"kind":"rain","x":x,"z":z,"start":tick,"end":tick+240,"radius":radius})
 if kind=="cool":heat-=.25;temperature-=2
 if kind=="wind":wind=-wind
 if kind=="spawn":add_person("Aster %d"%next_id,x,z)
 if kind in ["fire","lightning","quake","flood","tornado","meteor","drought","shield"]:disasters.append({"kind":kind,"x":x,"z":z,"start":tick,"end":tick+(2400 if kind=="shield" else 450 if kind!="lightning" else 20),"radius":radius})
 for p in people:
  var id=cell_at(p.x,p.z);var near=distance(Vector2(p.x,p.z),center)<=radius
  if not near and not conductive.has(id):continue
  var shielded=cells[id].shield>tick
  match kind:
   "heal":p.health=100.0;p.hunger=0.0;p.fatigue=0.0
   "fire":
    if not shielded and cells[id].fire>0:damage(p,24,"divine fire")
   "lightning":
    if not shielded:damage(p,110 if near else 75,"lightning conducted through water")
   "quake":
    if not shielded:damage(p,maxf(25,125-distance(Vector2(p.x,p.z),center)*14),"the earthquake")
   "meteor":
    if not shielded:damage(p,150,"a meteor impact")
   "resurrect":
    if possessed==p.id:possessed=-1
    release_cargo(p);p.path=[];p.queue=[];p.alive=true;p.health=100.0;p.hunger=0.0;p.task="hold";p.authority="God"
 for b in buildings:
  if kind=="heal" and distance(Vector2(b.x,b.z),center)<=radius:b.health=100.0
  if distance(Vector2(b.x,b.z),center)<=radius and kind in ["quake","meteor","lightning"]:
   if cells[cell_at(b.x,b.z)].shield<=tick:b.health=maxf(0,b.health-(85 if kind=="meteor" else 55))
 for a in animals:
  if distance(Vector2(a.x,a.z),center)<=radius:
   if kind in ["lightning","meteor"] and cells[cell_at(a.x,a.z)].shield<=tick:a.health=0.0;a.alive=false
   if kind=="heal":a.health=100.0;a.hunger=0.0
   if kind=="resurrect":a.health=100.0;a.alive=true
 if kind in ["raise","lower","quake","meteor"]:terrain_revision+=1
 if kind in ["forest","fire","meteor"]:ecology_revision+=1
 commands.append({"tick":tick,"actor":"god","action":kind,"x":x,"z":z})
 record(r.title,"%d cells affected. %s"%[touched.size(),"Electricity followed connected water through %d cells."%conductive.size() if kind=="lightning" else "The consequences are part of your world."],x,z)
 return r.title+" manifested."
func lift(id: int,x: float,z: float) -> String:
 var p=person(id)
 if p.is_empty() or not p.alive:return "Choose a living person."
 if not is_safe(x,z):return "Place them on dry land."
 if possessed==id:possessed=-1
 release_cargo(p);p.x=x;p.z=z;p.path=[];p.task="hold";p.authority="God";p.queue=[];ordered=true
 return p.name+" is standing where you placed them."
func evacuate() -> void:
 evacuated=true
 for p in people:
  if p.alive and p.id!=possessed:order(p.id,"rescue",-23.0+float(p.id%3),-3.0+float(p.id%3))
 record("Settlement evacuation","People hold at the refuge until you release their orders.",-20,-3)
func diplomacy(action: String) -> String:
 match action:
  "trade":
   if wood<20:return "Trade needs 20 timber."
   wood-=20;grain+=55;relation+=25;traded=true;record("Cedar pact","55 grain and rescue boats in exchange for 20 timber.",18,-8)
  "treaty":
   if relation<30:return "Build trust with trade or tribute first."
   treaty=true;relation+=10
  "tribute":
   if grain<15:return "Tribute needs 15 grain."
   grain-=15;relation+=20
  "threaten":relation-=35
 return "Trust %d. %s"%[relation,"Truce active." if treaty else "No treaty."]
func era_requirement() -> String:
 match era:
  0:
   if harvests<1:return "Harvest from a working farm."
   if not has_building("storehouse"):return "Complete a storehouse."
  1:
   if not has_building("market"):return "Complete a caravan market."
   if not has_building("workshop"):return "Complete a workshop."
   if not traded:return "Trade with Cedar Camp."
  2:
   if not has_building("windmill"):return "Complete a wind generator."
   if knowledge<80:return "Gather %d more knowledge."%ceili(80-knowledge)
  3:return "Build the observatory and sustain both settlements."
 return ""
func research() -> String:
 var reason=era_requirement()
 if not reason.is_empty():return reason
 era+=1;knowledge=0;record("A new age",Rules.ERAS[era]+" has begun.");return Rules.ERAS[era]+" unlocked."
func arrange_pair(first: int,second: int) -> String:
 var a=person(first);var b=person(second)
 if a.is_empty() or b.is_empty() or first==second:return "Choose two different adults."
 if not a.alive or not b.alive or a.age<18 or b.age<18:return "Both parents must be living adults."
 if a.pregnancy>0 or b.pregnancy>0:return "A child is already on the way."
 for parent in [a,b]:
  var former=person(parent.partner)
  if not former.is_empty() and former.pregnancy>0:return "Cancel the existing pregnancy before changing this family."
 for parent in [a,b]:
  var former=person(parent.partner)
  if not former.is_empty():former.partner=-1
 a.partner=second;b.partner=first
 var parent=a if a.sex=="F" else b
 parent.pregnancy=tick+DAY*2
 record("A new beginning",a.name+" and "+b.name+" are expecting a child.",a.x,a.z)
 return "A child is expected in two days. You may bless the birth, delay it, or cancel it."
func bless_birth(id: int) -> String:
 var p=person(id)
 if p.is_empty() or not p.alive or p.partner<0:return "Choose a living paired adult first."
 var partner=person(p.partner)
 if partner.is_empty() or (not partner.alive and p.pregnancy<=0):return "The other parent must be alive, or this parent must already be expecting."
 var baby=add_person("Nova %d"%next_id,p.x+.6,p.z,0.0,[p.id,partner.id]);baby.home=p.home
 p.pregnancy=0;partner.pregnancy=0;p.last_birth=tick;partner.last_birth=tick;births+=1
 record("A child is born",baby.name+", child of "+p.name+" and "+partner.name+".",p.x,p.z)
 return baby.name+" was born."
func cancel_birth(id: int) -> void:
 var p=person(id)
 if p.is_empty():return
 p.pregnancy=0
 var partner=person(p.partner)
 if not partner.is_empty():partner.pregnancy=0
func access_point(b: Dictionary,p: Dictionary) -> Vector2:
 if not solid_cells.has(cell_at(b.x,b.z)):return Vector2(b.x,b.z)
 var best=Vector2(b.x+1,b.z);var dist=INF
 for offset in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
  var point=Vector2(b.x,b.z)+offset
  if is_safe(point.x,point.y) and not solid_cells.has(cell_at(point.x,point.y)):
   var d=distance(Vector2(p.x,p.z),point)
   if d<dist:dist=d;best=point
 return best
func water_radius(c: Dictionary) -> float:
 return PLANET_RADIUS+c.e+c.water
func _nearest_building(kind: String,p: Dictionary,complete: bool=true) -> Dictionary:
 var found={};var best=INF
 for b in buildings:
  if b.kind!=kind or b.complete!=complete or b.health<=0:continue
  var d=distance(Vector2(p.x,p.z),Vector2(b.x,b.z))
  if d<best and is_safe(b.x,b.z):found=b;best=d
 return found
func _auto_job(p: Dictionary) -> void:
 if p.age<16:
  if not p.parents.is_empty():
   var parent=person(p.parents[0])
   if not parent.is_empty() and parent.alive and distance(Vector2(p.x,p.z),Vector2(parent.x,parent.z))>2:_set_route(p,"child",parent.x,parent.z)
  return
 if p.fatigue>75:p.task="rest";return
 if p.job=="Builder":
  for b in buildings:
   if not b.complete and b.health>0 and is_safe(b.x,b.z):
    var access=access_point(b,p)
    if _set_route(p,"build",access.x,access.y):p.target_id=b.id;return
 if p.job=="Farmer":
  var farm=_nearest_building("farm",p)
  if not farm.is_empty() and cells[cell_at(farm.x,farm.z)].dry_until<=tick:
   _set_route(p,"harvest",farm.x,farm.z);return
 # Haulers and free builders actually visit a forest rather than creating timber in place.
 for radius in [3,6,10,15]:
  for j in 12:
   var angle=(j*TAU/12)+float(p.id)*.7
   var x=p.x+cos(angle)*radius;var z=p.z+sin(angle)*radius;var c=cells[cell_at(x,z)]
   if c.forest and c.fire<=0 and is_safe(x,z):
    if _set_route(p,"gather",x,z):return
 p.task="idle";p.blocked="No safe work nearby. Place a farm, construction site, or restore a forest."
func _environment_step() -> void:
 var transfers={};var remove=[]
 for id in active_cells.keys():
  var c=cells[id]
  if c.water>.12 or c.moisture>.65:
   if c.fire>0:c.fire=0.0;ecology_revision+=1
  if c.fire>0:
   c.burn+=DT*2;c.fuel=maxf(0,c.fuel-DT*.10);c.moisture=maxf(0,c.moisture-.012)
   if c.fuel<=0 or c.burn>65:c.fire=0.0;c.ash=1.0;c.forest=false;ecology_revision+=1
   elif tick%10==0:
    c.ash=minf(1,c.ash+.04)
    if c.forest and c.burn>4:c.forest=false;ecology_revision+=1
    var n=int(id)/W*W+posmod(int(id)%W+wind,W)
    if weather_rng.randf()<.65:_ignite(n,.75)
    for next in neighbors(id):
     if weather_rng.randf()<.12:_ignite(next,.65)
  var base=maxf(0,-c.e);var free=maxf(0,c.water-base)
  if free>.015:
   var budget=free*.28
   for n in neighbors(id):
    var other=cells[n];var diff=c.e+c.water-other.e-other.water
    if diff>.04 and budget>0:
     var amount=minf(budget,diff*.07);budget-=amount
     transfers[id]=transfers.get(id,0.0)-amount;transfers[n]=transfers.get(n,0.0)+amount
   c.water=maxf(base,c.water-.0009)
  c.moisture=maxf(.0,c.moisture-.00008)
  if c.fire<=0 and free<.015 and c.electric<=tick and c.ash<=.01:remove.append(id)
 for id in transfers:
  var c=cells[id];c.water=maxf(maxf(0,-c.e),c.water+transfers[id]);_activate(id)
  if c.water>.12:c.fire=0.0
 for id in remove:
  if not transfers.has(id):active_cells.erase(id)
func _flood_step() -> void:
 var protected=has_building("levee") or elevation(4,0)>.9
 var start=cell_at(7,0);var frontier=[start];var seen={start:true};var cursor=0
 while cursor<frontier.size() and cursor<2300:
  var id: int=frontier[cursor];cursor+=1;var c=cells[id];var p=position(id)
  if abs(p.x)>26 or abs(p.y)>19:continue
  var level=flood
  if protected and p.x<5:level=minf(level,.22)
  if c.e<level:
   c.water=maxf(c.water,level-c.e);_activate(id)
   for n in neighbors(id):
    if not seen.has(n):seen[n]=true;frontier.append(n)
func _needs(p: Dictionary) -> void:
 p.age+=DT/(DAY*DT*40);p.hunger+=DT*(.012 if policy!="Rationing" else .008);p.fatigue+=DT*.008
 if p.hunger>12 and grain>=1:grain-=1;p.hunger=maxf(0,p.hunger-16)
 if p.hunger>90:damage(p,DT*.5,"starvation")
 var c=cells[cell_at(p.x,p.z)]
 if c.shield<=tick:
  if c.fire>0:damage(p,DT*35*c.fire,"fire")
  if c.water>.55 and not traded:damage(p,DT*16.0*minf(2,c.water),"drowning")
  if c.electric>tick and c.water>.1:damage(p,DT*45,"electrified water")
 for d in disasters:
  if d.kind=="tornado" and distance(Vector2(p.x,p.z),Vector2(d.x,d.z))<d.radius and c.shield<=tick:
   damage(p,DT*14,"the tornado")
   var pull=wrapped_delta(Vector2(p.x,p.z),Vector2(d.x,d.z)).normalized()*DT*.4;p.x+=pull.x;p.z+=pull.y
func _move(p: Dictionary) -> bool:
 if p.path.is_empty():return false
 var point=position(p.path[0]);var delta=wrapped_delta(Vector2(p.x,p.z),point)
 if not is_safe(point.x,point.y) or cells[p.path[0]].fire>.1:
  p.blocked_task=p.task;p.path=[];p.task="blocked";p.blocked="Your route is dangerous. The order is retained; lift them or make the route safe.";return true
 var length=delta.length();var speed=2.0 if p.age>=16 else 1.4
 if length<=speed*DT:
  p.x=point.x;p.z=point.y;p.path.pop_front()
 else:
  var direction=delta/length*speed*DT;p.x=wrapf(p.x+direction.x,-W*CELL/2,W*CELL/2);p.z+=direction.y
 return true
func _finish(p: Dictionary) -> void:
 if not p.queue.is_empty():
  var q=p.queue[0];var result=order(p.id,q.task,q.x,q.z)
  if result.ends_with(" ordered."):p.queue.pop_front()
  else:p.task="blocked_queue";p.path=[];p.blocked="Queued order blocked: "+result
  return
 p.task="hold" if p.authority=="God" else "idle"
func _work(p: Dictionary) -> void:
 match p.task:
  "move","rescue","child":_finish(p)
  "hold","fight","possessed","dead":return
  "rest":
   p.fatigue=maxf(0,p.fatigue-DT*5);p.health=minf(100,p.health+DT*.5)
   if p.fatigue<=0:_finish(p)
  "blocked":
   if tick%20==p.id%20 and is_safe(p.target[0],p.target[1]):_set_route(p,p.blocked_task if not p.blocked_task.is_empty() else "move",p.target[0],p.target[1])
  "blocked_queue":
   if tick%20==p.id%20:_finish(p)
  "gather":
   var c=cells[cell_at(p.x,p.z)]
   if not c.forest:p.blocked="No timber remains here.";_finish(p);return
   p.work+=DT
   if p.work>=4:
    wood+=4;c.forest=false;c.fuel=1.0;ecology_revision+=1;p.work=0.0;_finish(p)
  "harvest":
   p.work+=DT
   if p.work>=6:
    var destination=_nearest_building("storehouse",p)
    if destination.is_empty():destination={"x":-6.0,"z":0.0}
    p.cargo=2.0;reservations[str(p.id)]="grain";harvests+=1
    var access=access_point(destination,p)
    if not _set_route(p,"deliver",access.x,access.y):release_cargo(p);p.task="blocked"
  "deliver":grain+=p.cargo;p.cargo=0.0;reservations.erase(str(p.id));_finish(p)
  "build":
   var found=false
   for b in buildings:
    if b.id==p.target_id and not b.complete and b.health>0 and distance(Vector2(p.x,p.z),Vector2(b.x,b.z))<2:
     found=true;b.work+=DT*3
     if b.work>=Rules.BUILDINGS[b.kind].work:b.complete=true;record("Construction complete",Rules.BUILDINGS[b.kind].title+" is ready.",b.x,b.z);_finish(p)
   if not found:_finish(p)
 if p.task=="idle" and p.authority=="Auto":_auto_job(p)
func _animal_step() -> void:
 for a in animals:
  if not a.alive:continue
  a.hunger+=DT*.015;var c=cells[cell_at(a.x,a.z)]
  if c.shield<=tick:
   if c.fire>0:a.health=maxf(0,a.health-DT*30)
   if c.water>.55:a.health=maxf(0,a.health-DT*12)
   if c.electric>tick:a.health=maxf(0,a.health-DT*45)
  if a.health<=0:a.alive=false;record("An animal lost",a.name+" died.",a.x,a.z);continue
  if a.hunger>20:
   if a.species=="deer":a.hunger=maxf(0,a.hunger-DT*4)
   elif grain>0:grain-=DT*.002;a.hunger=maxf(0,a.hunger-DT*3)
  if a.mode=="Stay":continue
  var owner=person(a.owner)
  if a.mode=="Follow" and not owner.is_empty() and owner.alive:a.target=[owner.x+.9,owner.z+.9]
  elif tick>=a.wait:
   a.target=[a.x+citizen_rng.randf_range(-3,3),a.z+citizen_rng.randf_range(-3,3)];a.wait=tick+citizen_rng.randi_range(50,150)
  var delta=wrapped_delta(Vector2(a.x,a.z),Vector2(a.target[0],a.target[1]))
  if delta.length()>.6:
   var direction=delta.normalized()*DT*1.6;var x=a.x+direction.x;var z=a.z+direction.y
   if is_safe(x,z) and not solid_cells.has(cell_at(x,z)) and cells[cell_at(x,z)].fire<=0:a.x=wrapf(x,-W*CELL/2,W*CELL/2);a.z=clampf(z,-62,62)
func step() -> void:
 if paused:return
 tick+=1;energy=minf(100,energy+DT*.10)
 if tick==DAY:weather="Storm forecast";record("Storm watch","Rain upstream on day three. Protect the village, evacuate, or arrange rescue boats.",7,0)
 if tick==DAY*2:weather="River flooding";record("A dangerous flood","Water is crossing the riverbanks. People in deep water will drown.",7,0)
 if tick>=DAY*2 and tick<DAY*3:flood=minf(1.25,flood+DT*.015)
 elif tick>=DAY*3:flood=maxf(0,flood-DT*.015)
 if tick==DAY*3:storm_done=true;weather="Clearing skies"
 if tick%10==0 and flood>0:_flood_step()
 if tick%2==0:_environment_step()
 for d in disasters.duplicate():
  if tick>=d.end:disasters.erase(d)
  elif d.kind=="rain" and tick%10==0:
   for z in range(-ceili(d.radius),ceili(d.radius)+1):
    for x in range(-ceili(d.radius),ceili(d.radius)+1):
     if Vector2(x,z).length()<=d.radius:_wet(cell_at(d.x+x,d.z+z),.02)
 for b in buildings:
  var c=cells[cell_at(b.x,b.z)]
  if b.health>0 and c.shield<=tick:
   if c.fire>0:b.health=maxf(0,b.health-DT*8*c.fire)
   if c.water>.8:b.health=maxf(0,b.health-DT*.2*c.water)
 for p in people:
  if not p.alive:continue
  _needs(p)
  if not p.alive or p.task=="possessed":continue
  if not _move(p):_work(p)
 _animal_step()
 if tick%100==0:
  knowledge+=1+(2 if has_building("workshop") else 0)
  if not treaty and relation<0 and faction_rng.randf()<.1:
   var guards=0
   for p in people:
    if p.alive and p.task=="fight":guards+=1
   if guards<2:grain=maxf(0,grain-12);record("Stores raided","Cedar Camp took 12 grain. Post two guards or negotiate a treaty.",18,-8)
  for p in people.duplicate():
   if p.alive and p.pregnancy>0 and tick>=p.pregnancy and reproduction!="Paused":bless_birth(p.id)
 if tick%600==0 and reproduction!="Paused" and grain>alive_count()*2:
  var beds=0;var expected=0
  for b in buildings:
   if b.kind=="home" and b.complete and b.health>0:beds+=4
  for p in people:
   if p.alive and p.pregnancy>0:expected+=1
  if beds>alive_count()+expected:
   var first={}
   for p in people:
    if not p.alive or p.age<18 or p.health<=70 or p.pregnancy>0 or tick-p.last_birth<=DAY*3:continue
    if p.partner>=0:
     var partner=person(p.partner)
     if not partner.is_empty() and partner.alive and partner.age>=18 and partner.pregnancy==0 and tick-partner.last_birth>DAY*3:
      arrange_pair(p.id,partner.id);break
    elif first.is_empty():first=p
    elif p.sex!=first.sex:arrange_pair(first.id,p.id);break
 if tick%(DAY/4)==0:
  for c in cells:c.moisture=maxf(0,c.moisture-.08)
 if tick%(DAY*2)==0:
  for c in cells:
   if c.ash>0:c.ash=maxf(0,c.ash-.08)
   if not c.forest and c.fuel<4 and c.moisture>.3 and c.e>.15 and c.fire<=0 and c.dry_until<=tick:
    if weather_rng.randf()<.20:c.forest=true;c.fuel=8.0;ecology_revision+=1
 if tick%(DAY*10)==0:
  var forests=0
  for c in cells:
   if c.forest:forests+=1
  heat+=(.08 if era>=2 else .01)-float(forests)*.000008-(.06 if has_building("windmill") else 0);climate_history.append(heat)
 temperature=18+sin(float(tick)/(DAY*40)*TAU)*8+heat
 if tick>DAY*3+120 and outcome.is_empty():
  if alive_count()>=8 and food_route_working():outcome="River Test complete";record(outcome,"At least eight people survived with a working food supply.")
  elif alive_count()<8:outcome="A recoverable world";record(outcome,"You may resurrect your people or begin again.")
 if tick%10==0:
  if grain>20 and food_route_working() and alive_count()>=8 and is_safe(-20,-5):supplied_ticks+=10
  else:supplied_ticks=0
 if has_building("observatory") and supplied_ticks>=DAY*40 and outcome!="Stewardship complete":outcome="Stewardship complete";record(outcome,"Your observatory watches over a thriving world.")
func food_route_working() -> bool:
 if grain<=0:return false
 if traded:return true
 if not has_building("storehouse"):return false
 for p in people:
  if p.alive and p.job=="Farmer":
   var farm=_nearest_building("farm",p);var store=_nearest_building("storehouse",p)
   if not farm.is_empty() and not store.is_empty() and not pathfind(cell_at(farm.x,farm.z),cell_at(access_point(store,p).x,access_point(store,p).y)).is_empty():return true
 return false
func objectives() -> Array:return [inspected,ordered,has_building("storehouse"),births>0,has_building("observatory")]
func snapshot() -> Dictionary:
 var state={"version":VERSION,"seed":seed_value,"rng":[str(weather_rng.state),str(citizen_rng.state),str(faction_rng.state)]}
 for key in ["tick","paused","sandbox","energy","grain","wood","knowledge","era","relation","treaty","evacuated","traded","storm_done","flood","heat","temperature","wind","next_id","possessed","inspected","ordered","harvests","active_faction","policy","reproduction","births","cells","people","buildings","animals","disasters","events","commands","reservations","active_cells","weather","outcome","climate_history","supplied_ticks","terrain_revision","ecology_revision"]:state[key]=get(key)
 return state
func _numbers(d: Dictionary,keys: Array) -> bool:
 for key in keys:
  if not d.has(key) or not (d[key] is int or d[key] is float) or not is_finite(float(d[key])):return false
 return true
func valid_state(data: Dictionary) -> bool:
 if data.get("version")!=VERSION or not data.get("cells") is Array or data.cells.size()!=W*H:return false
 if not data.get("rng") is Array or data.rng.size()!=3:return false
 for value in data.rng:
  if not value is String or not value.is_valid_int():return false
 var schema=snapshot()
 for key in schema:
  if not data.has(key):return false
  if schema[key] is int or schema[key] is float:
   if not _numbers(data,[key]):return false
  elif typeof(schema[key])!=typeof(data[key]):return false
 if data.era<0 or data.era>3 or data.tick<0 or data.people.size()>2000 or data.animals.size()>2000:return false
 var ids={}
 for i in data.cells.size():
  var c=data.cells[i]
  if not c is Dictionary or not c.has_all(["id","forest","ice"]) or c.id!=i or not c.forest is bool or not c.ice is bool:return false
  if not _numbers(c,["e","water","moisture","fuel","fire","burn","electric","shield","ash","dry_until"]):return false
 for p in data.people:
  if not p is Dictionary or not p.has_all(["id","name","job","task","authority","alive","target","path","queue","parents","sex","blocked","blocked_task"]):return false
  if not p.id is int or ids.has(p.id) or not p.alive is bool:return false
  ids[p.id]=true
  for key in ["name","job","task","authority","sex","blocked","blocked_task"]:
   if not p[key] is String:return false
  if not _numbers(p,["x","z","health","hunger","fatigue","age","cargo","faction","home","work","target_id","partner","pregnancy","birth_tick","last_birth"]):return false
  for field in ["target","path","queue","parents"]:
   if not p[field] is Array:return false
  if p.target.size()!=2 or not _numbers({"x":p.target[0],"z":p.target[1]},["x","z"]):return false
  for id in p.path:
   if not id is int or id<0 or id>=W*H:return false
  for q in p.queue:
   if not q is Dictionary or not q.get("task") is String or not _numbers(q,["x","z"]):return false
 for b in data.buildings:
  if not b is Dictionary or not b.has_all(["id","kind","complete"]) or not b.id is int or ids.has(b.id):return false
  if not b.kind is String or not Rules.BUILDINGS.has(b.kind) or not b.complete is bool or not _numbers(b,["x","z","work","health"]):return false
  ids[b.id]=true
 for a in data.animals:
  if not a is Dictionary or not a.has_all(["id","name","species","alive","mode","target"]) or not a.alive is bool:return false
  if not a.species in ["dog","cat","deer"] or not a.mode in ["Follow","Roam","Stay"] or not a.target is Array or a.target.size()!=2:return false
  if not _numbers(a,["id","x","z","health","hunger","owner","wait"]):return false
  if not _numbers({"x":a.target[0],"z":a.target[1]},["x","z"]):return false
  if not a.name is String or not a.id is int or ids.has(a.id):return false
  ids[a.id]=true
 for d in data.disasters:
  if not d is Dictionary or not d.get("kind") is String or not _numbers(d,["x","z","start","end","radius"]):return false
 for e in data.events:
  if not e is Dictionary or not e.get("title") is String or not e.get("detail") is String or not _numbers(e,["tick","x","z"]):return false
 for id in data.active_cells:
  if not id is int or id<0 or id>=W*H:return false
 return true
func restore(data: Dictionary) -> bool:
 if not valid_state(data):return false
 for key in snapshot():
  if key not in ["version","seed","rng"]:set(key,data[key])
 solid_cells.clear()
 for b in buildings:
  if b.kind in ["home","storehouse","market","workshop","windmill","observatory"]:solid_cells[cell_at(b.x,b.z)]=b.id
 seed_value=int(data.seed);weather_rng.state=int(data.rng[0]);citizen_rng.state=int(data.rng[1]);faction_rng.state=int(data.rng[2]);return true
func state_hash() -> String:return var_to_bytes(snapshot()).hex_encode().sha256_text()
func save_world(path: String="user://worldkeeper-planet.json") -> bool:
 var payload=Marshalls.raw_to_base64(var_to_bytes(snapshot()))
 var text=JSON.stringify({"version":VERSION,"encoding":"godot-variant-base64","state":payload,"digest":payload.sha256_text()})
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(text);file.close()
 var test=WorldSimulation.new()
 if not test.restore(bytes_to_var(Marshalls.base64_to_raw(payload))):return false
 var absolute=ProjectSettings.globalize_path(path)
 if FileAccess.file_exists(path):
  if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(absolute+".bak")
  DirAccess.rename_absolute(absolute,absolute+".bak")
 return DirAccess.rename_absolute(absolute+".tmp",absolute)==OK
func load_world(path: String="user://worldkeeper-planet.json") -> bool:
 for candidate in [path,path+".bak"]:
  if not FileAccess.file_exists(candidate):continue
  var parser=JSON.new()
  if parser.parse(FileAccess.get_file_as_string(candidate))!=OK:continue
  var e=parser.data
  if not e is Dictionary or e.get("version")!=VERSION or not e.get("state") is String:continue
  if e.get("digest")!=e.state.sha256_text():continue
  var data=bytes_to_var(Marshalls.base64_to_raw(e.state))
  if data is Dictionary and restore(data):return true
 return false
