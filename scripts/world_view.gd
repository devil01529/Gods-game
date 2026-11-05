class_name WorldView
extends Node3D
const Sim = preload("res://scripts/simulation.gd")
var sim: WorldSimulation
var terrain: MeshInstance3D
var water: MeshInstance3D
var vegetation = Node3D.new()
var structures = Node3D.new()
var citizens = Node3D.new()
var effects = Node3D.new()
var globe = Node3D.new()
var local_world = Node3D.new()
var person_nodes = {}
var building_nodes = {}
var ring: MeshInstance3D
var brush: MeshInstance3D
var materials = {}
var globe_mode = false
var overlay = "Natural"
var selected = -1
var animation_time = 0.0
var rain: CPUParticles3D
var smoke: CPUParticles3D
var birds: Array=[]
var fire_nodes: Array = []

func material(color: Color,roughness: float=0.9) -> StandardMaterial3D:
 var key=color.to_html()+str(roughness)
 if materials.has(key): return materials[key]
 var mat=StandardMaterial3D.new()
 mat.albedo_color=color; mat.roughness=roughness
 materials[key]=mat
 return mat
func mesh_node(mesh: Mesh,mat: Material,pos: Vector3,parent: Node3D) -> MeshInstance3D:
 var node=MeshInstance3D.new()
 node.mesh=mesh; node.material_override=mat; node.position=pos
 parent.add_child(node)
 return node
func box(size: Vector3,color: Color,pos: Vector3,parent: Node3D) -> MeshInstance3D:
 var mesh=BoxMesh.new(); mesh.size=size
 return mesh_node(mesh,material(color),pos,parent)
func cylinder(bottom: float,top: float,height: float,color: Color,pos: Vector3,parent: Node3D,sides: int=8) -> MeshInstance3D:
 var mesh=CylinderMesh.new(); mesh.bottom_radius=bottom; mesh.top_radius=top; mesh.height=height; mesh.radial_segments=sides
 return mesh_node(mesh,material(color),pos,parent)
func sphere(radius: float,color: Color,pos: Vector3,parent: Node3D) -> MeshInstance3D:
 var mesh=SphereMesh.new(); mesh.radius=radius; mesh.height=radius*2; mesh.radial_segments=10; mesh.rings=5
 return mesh_node(mesh,material(color),pos,parent)
func setup(state: WorldSimulation) -> void:
 sim=state
 add_child(local_world); local_world.add_child(vegetation); local_world.add_child(structures); local_world.add_child(citizens); local_world.add_child(effects)
 add_child(globe); globe.visible=false
 terrain=MeshInstance3D.new(); local_world.add_child(terrain)
 var water_mesh=PlaneMesh.new(); water_mesh.size=Vector2(Sim.W*Sim.CELL,Sim.H*Sim.CELL)
 var shader=Shader.new()
 shader.code="shader_type spatial; render_mode cull_disabled; uniform vec4 water_color: source_color = vec4(0.13,0.43,0.48,1.0); void vertex(){ VERTEX.y += sin(VERTEX.x*2.5+TIME)*cos(VERTEX.z*2.0+TIME*0.7)*0.025; } void fragment(){ float ripple=sin(UV.x*500.0+TIME*1.2)*cos(UV.y*400.0+TIME); ALBEDO=water_color.rgb+ripple*0.018; ROUGHNESS=0.28; METALLIC=0.2; }"
 var water_mat=ShaderMaterial.new(); water_mat.shader=shader
 water=mesh_node(water_mesh,water_mat,Vector3(0,0.02,0),local_world)
 var ocean_mesh=PlaneMesh.new(); ocean_mesh.size=Vector2(400,400)
 mesh_node(ocean_mesh,material(Color("315860")),Vector3(0,-1.5,0),local_world)
 ring=make_ring(0.48,Color("ffe5a1"),local_world); ring.visible=false
 brush=make_ring(3,Color("e4cf92"),local_world); brush.visible=false
 rebuild_terrain(); rebuild_vegetation(); make_details(); rebuild_globe(); sync()
func make_ring(radius: float,color: Color,parent: Node3D) -> MeshInstance3D:
 var mesh=TorusMesh.new(); mesh.inner_radius=radius-0.035; mesh.outer_radius=radius+0.035; mesh.rings=32; mesh.ring_segments=6
 var mat=material(color).duplicate(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 return mesh_node(mesh,mat,Vector3.ZERO,parent)
func cell_color(c: Dictionary) -> Color:
 if overlay=="Flood risk": return Color("a75646") if c.e<0.63 else Color("75a387")
 if overlay=="Temperature": return Color("dba86c").lerp(Color("6ba6a5"),clampf(c.e/4,0,1))
 if c.ice: return Color("d9e6db")
 if c.e<0: return Color("659b91")
 if c.e<0.13: return Color("b9b086")
 if c.e>2.2: return Color("819584").lerp(Color("b2bdac"),minf(1,(c.e-2.2)/2))
 if c.fire>0: return Color("735c3a")
 var p=sim.position(c.id)
 var tint=sin(p.x*0.5)*cos(p.y*0.4)*0.018
 return Color(0.40+tint,0.52+tint,0.30+tint) if c.forest else Color(0.53+tint,0.61+tint,0.37+tint)
func corner_height(x: int,z: int) -> float:
 var height=0.0
 for dz in [-1,0]:
  for dx in [-1,0]:
   height+=float(sim.cells[clampi(z+dz,0,Sim.H-1)*Sim.W+posmod(x+dx,Sim.W)].e)
 return height*0.25
func rebuild_terrain() -> void:
 var vertices=PackedVector3Array(); var colors=PackedColorArray(); var normals=PackedVector3Array()
 var indices=[0,1,2,0,2,3]
 for c in sim.cells:
  var p=sim.position(c.id)
  var x=int(c.id)%Sim.W; var z=int(c.id)/Sim.W
  var half=Sim.CELL*0.5
  var corners=[Vector3(p.x-half,corner_height(x,z),p.y-half),Vector3(p.x+half,corner_height(x+1,z),p.y-half),Vector3(p.x+half,corner_height(x+1,z+1),p.y+half),Vector3(p.x-half,corner_height(x,z+1),p.y+half)]
  var col=cell_color(c)
  for tri in [[0,1,2],[0,2,3]]:
   var normal=(corners[tri[2]]-corners[tri[0]]).cross(corners[tri[1]]-corners[tri[0]]).normalized()
   for index in tri:
    vertices.append(corners[index]); normals.append(normal); colors.append(col)
 var arrays=[]; arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_COLOR]=colors
 var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.roughness=1.0; mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 terrain.mesh=mesh; terrain.material_override=mat
func multimesh(mesh: Mesh,mat: Material,transforms: Array) -> void:
 var multi=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=mesh; multi.instance_count=transforms.size()
 for i in transforms.size(): multi.set_instance_transform(i,transforms[i])
 var instance=MultiMeshInstance3D.new(); instance.multimesh=multi; instance.material_override=mat
 vegetation.add_child(instance)
func rebuild_vegetation() -> void:
 for child in vegetation.get_children(): child.free()
 var trunks: Array=[]; var crowns: Array=[]; var tips: Array=[]; var rocks: Array=[]
 for c in sim.cells:
  if c.id%3!=0 or c.ice or c.e<0.15: continue
  var p=sim.position(c.id)
  p+=Vector2(sin(c.id*17.1),cos(c.id*19.3))*0.23
  if p.x>-13 and p.x<1 and abs(p.y)<9: continue
  var size=0.65+abs(sin(c.id*2.3))*0.7
  var basis=Basis.IDENTITY.scaled(Vector3.ONE*size)
  if c.forest:
   trunks.append(Transform3D(basis,Vector3(p.x,c.e+0.5*size,p.y)))
   crowns.append(Transform3D(basis,Vector3(p.x,c.e+1.05*size,p.y)))
   tips.append(Transform3D(basis,Vector3(p.x,c.e+1.65*size,p.y)))
  elif c.id%21==0:
   rocks.append(Transform3D(Basis.from_euler(Vector3(0,c.id,0)).scaled(Vector3(size,0.7*size,size)),Vector3(p.x,c.e+0.15,p.y)))
 var trunk=CylinderMesh.new(); trunk.bottom_radius=0.10; trunk.top_radius=0.06; trunk.height=1; trunk.radial_segments=5
 var crown=CylinderMesh.new(); crown.bottom_radius=0.62; crown.top_radius=0; crown.height=1.4; crown.radial_segments=7
 var tip=CylinderMesh.new(); tip.bottom_radius=0.44; tip.top_radius=0; tip.height=1.2; tip.radial_segments=7
 var rock=SphereMesh.new(); rock.radius=0.37; rock.height=0.55; rock.radial_segments=6; rock.rings=3
 multimesh(trunk,material(Color("66533d")),trunks)
 multimesh(crown,material(Color("315b47")),crowns)
 multimesh(tip,material(Color("487858")),tips)
 multimesh(rock,material(Color("91998b")),rocks)
func make_details() -> void:
 # Footpaths and stepping stones tie the settlement together.
 for i in 44:
  var x=-12+i*0.29; var z=sin(i*0.17)*0.6
  box(Vector3(0.34,0.025,0.8),Color("b3a786"),Vector3(x,sim.elevation(x,z)+0.025,z),structures)
 for i in 18:
  var z=-7+i*0.65
  box(Vector3(0.6,0.02,0.5),Color("b8aa8b"),Vector3(-6,sim.elevation(-6,z)+0.02,z),structures)
 # Refuge and neighboring camp remain recognizable at a glance.
 world_label("WESTERN REFUGE",Vector3(-20,3.8,-6),structures,26)
 world_label("RIVERHAVEN",Vector3(-6,3.3,-5),structures,30)
 world_label("CEDAR CAMP",Vector3(18,3,-8),structures,25)
 for i in 3: tent(Vector3(17+i*1.8,sim.elevation(17+i*1.8,-9),-9),structures)
 make_atmosphere()
 var fire=OmniLight3D.new(); fire.light_color=Color("ffb65b"); fire.light_energy=1.4; fire.omni_range=4; fire.position=Vector3(-7,1,1.4); structures.add_child(fire)
 for i in 7:
  var a=i*TAU/7
  sphere(0.15,Color("777c68"),Vector3(-7+cos(a)*0.35,sim.elevation(-7,1.4)+0.1,1.4+sin(a)*0.35),structures)
 cylinder(0.17,0,0.5,Color("efbc64"),Vector3(-7,sim.elevation(-7,1.4)+0.3,1.4),structures)
func make_atmosphere() -> void:
 var smoke_mesh=SphereMesh.new(); smoke_mesh.radius=0.12; smoke_mesh.height=0.24; smoke_mesh.radial_segments=6; smoke_mesh.rings=3
 var smoke_mat=material(Color(0.69,0.73,0.65,0.3)).duplicate(); smoke_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; smoke_mesh.material=smoke_mat
 smoke=CPUParticles3D.new(); smoke.mesh=smoke_mesh; smoke.amount=16; smoke.lifetime=4; smoke.position=Vector3(-7,1.1,1.4); smoke.direction=Vector3(0,1,0); smoke.gravity=Vector3(0.12,0.14,0); smoke.initial_velocity_min=0.15; smoke.initial_velocity_max=0.3; smoke.scale_amount_min=0.5; smoke.scale_amount_max=2.5; smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; effects.add_child(smoke)
 var rain_mesh=BoxMesh.new(); rain_mesh.size=Vector3(0.018,0.28,0.018); rain_mesh.material=material(Color("b5cbd0"))
 rain=CPUParticles3D.new(); rain.mesh=rain_mesh; rain.amount=420; rain.lifetime=1.5; rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents=Vector3(16,0,12); rain.position=Vector3(-4,13,0); rain.direction=Vector3(0,-1,0); rain.gravity=Vector3(0,-2,0); rain.initial_velocity_min=8; rain.initial_velocity_max=10; rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; rain.emitting=false; effects.add_child(rain)
 for i in 5:
  var bird=Node3D.new(); effects.add_child(bird)
  for side in [-1,1]:
   var wing=box(Vector3(0.25,0.025,0.08),Color("40574a"),Vector3(side*0.13,0,0),bird); wing.rotation.z=side*0.3
  birds.append(bird)
func world_label(text: String,pos: Vector3,parent: Node3D,size: int=24) -> void:
 var label=Label3D.new(); label.text=text; label.position=pos; label.font_size=size; label.pixel_size=0.009; label.modulate=Color("f8f1d9"); label.outline_modulate=Color("26423c"); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test=true
 parent.add_child(label)
func tent(pos: Vector3,parent: Node3D) -> void:
 var node=Node3D.new(); parent.add_child(node); node.position=pos
 cylinder(0.9,0,1.4,Color("d7ba8d"),Vector3(0,0.7,0),node,4)
 cylinder(0.035,0.035,1.8,Color("63513a"),Vector3(0,0.9,0),node)
func make_building(b: Dictionary) -> Node3D:
 var node=Node3D.new(); structures.add_child(node)
 var base_color=Color("d0c3a0"); var roof_color=Color("956e50")
 var kind=b.kind
 if kind=="farm":
  box(Vector3(2.6,0.05,2.2),Color("665b38"),Vector3(0,0.03,0),node)
  for i in 7:
   box(Vector3(0.09,0.23,1.9),Color("b7b66b"),Vector3(-1.1+i*0.36,0.15,0),node)
  for i in 4:
   for j in [-1,1]: cylinder(0.035,0.035,0.55,Color("aa8a5b"),Vector3(-1.2+i*0.8,0.25,j*1.1),node)
 elif kind=="well":
  cylinder(0.6,0.6,0.5,Color("a6a58c"),Vector3(0,0.25,0),node,12)
  cylinder(0.42,0.42,0.51,Color("325c64"),Vector3(0,0.26,0),node,12)
  for x in [-0.55,0.55]: box(Vector3(0.1,1.4,0.1),roof_color,Vector3(x,0.7,0),node)
  cylinder(0.85,0,0.55,roof_color,Vector3(0,1.5,0),node,4)
 elif kind=="levee":
  for i in 5: box(Vector3(0.5,0.65+float(i%2)*0.1,0.6),Color("949b8a"),Vector3(-1+i*0.5,0.35,0),node)
 elif kind=="observatory":
  cylinder(1.2,0.9,1.8,base_color,Vector3(0,0.9,0),node,16)
  sphere(1.0,Color("7da4a6"),Vector3(0,1.8,0),node)
  var telescope=cylinder(0.22,0.3,1.8,Color("e2d9bf"),Vector3(0.6,2.4,0),node); telescope.rotation.z=-0.8
 else:
  var size=1.4 if kind=="home" else 1.9
  box(Vector3(size,1.0,size*0.8),base_color,Vector3(0,0.5,0),node)
  var roof=cylinder(size*0.88,0,0.85,roof_color,Vector3(0,1.4,0),node,4); roof.rotation.y=PI/4
  box(Vector3(0.3,0.6,0.03),Color("584d3d"),Vector3(0,0.3,size*0.4+0.02),node)
  for x in [-size*0.33,size*0.33]: box(Vector3(0.21,0.24,0.04),Color("e6ca7e"),Vector3(x,0.67,size*0.4+0.02),node)
  if kind in ["storehouse","workshop","market"]:
   for i in 3: cylinder(0.18,0.18,0.4,Color("b39461"),Vector3(size*0.7,0.2,-0.4+i*0.4),node)
  if kind=="windmill":
   cylinder(0.23,0.15,3.8,base_color,Vector3(0,2,0),node)
   var blades=Node3D.new(); blades.name="Blades"; node.add_child(blades); blades.position=Vector3(0,3.6,0.25)
   for i in 4:
    var blade=box(Vector3(0.13,1.7,0.07),Color("e2dbc2"),Vector3.ZERO,blades); blade.position=Vector3(sin(i*PI/2)*0.8,cos(i*PI/2)*0.8,0); blade.rotation.z=-i*PI/2
 node.position=Vector3(b.x,sim.elevation(b.x,b.z)+0.05,b.z)
 building_nodes[b.id]=node
 return node
func make_person(p: Dictionary) -> Node3D:
 var node=Node3D.new(); citizens.add_child(node)
 var colors=[Color("bd7757"),Color("e4c279"),Color("729eab"),Color("a59a74")]
 cylinder(0.14,0.1,0.34,colors[int(p.id)%4],Vector3(0,0.28,0),node)
 sphere(0.12,Color("d6ae86"),Vector3(0,0.56,0),node)
 sphere(0.115,Color("5c4b37"),Vector3(0,0.61,-0.025),node)
 for x in [-0.065,0.065]: box(Vector3(0.06,0.18,0.07),Color("5e6253"),Vector3(x,0.09,0),node)
 var raft=cylinder(0.36,0.36,0.07,Color("98734c"),Vector3(0,0.02,0),node,10); raft.name="Raft"; raft.visible=false
 var cargo=box(Vector3(0.18,0.2,0.18),Color("c6aa70"),Vector3(0,0.27,0.19),node); cargo.name="Cargo"
 person_nodes[p.id]=node
 return node
func sync() -> void:
 for p in sim.people:
  if not person_nodes.has(p.id): make_person(p)
  var node: Node3D=person_nodes[p.id]
  node.visible=p.alive
  node.position=Vector3(p.x,sim.elevation(p.x,p.z)+0.07,p.z)
  node.get_node("Cargo").visible=p.cargo>0
  node.get_node("Raft").visible=sim.traded and sim.elevation(p.x,p.z)<sim.flood
  if node.get_node("Raft").visible: node.position.y=sim.flood+0.07
  if not p.path.is_empty():
   var dest=sim.position(p.path[0]); var delta=dest-Vector2(p.x,p.z)
   if delta.length()>0.01: node.rotation.y=atan2(delta.x,delta.y)
 for b in sim.buildings:
  if not building_nodes.has(b.id): make_building(b)
  var node: Node3D=building_nodes[b.id]
  node.scale.y=1.0 if b.complete else maxf(0.08,b.work/float(WorldRules.BUILDINGS[b.kind].work))
  node.visible=b.health>0
  node.position.y=sim.elevation(b.x,b.z)+0.05
 for id in building_nodes.keys():
  var found=false
  for b in sim.buildings:
   if b.id==id: found=true
  if not found: building_nodes[id].queue_free(); building_nodes.erase(id)
 ring.visible=selected>=0 and not globe_mode
 var person=sim.person(selected)
 if not person.is_empty(): ring.position=Vector3(person.x,sim.elevation(person.x,person.z)+0.09,person.z)
 water.position.y=maxf(0.02,sim.flood)
 if sim.tick%8==0: update_fire()
func update_fire() -> void:
 for node in fire_nodes: node.queue_free()
 fire_nodes.clear()
 for c in sim.cells:
  if c.fire<=0 or c.id%3!=0: continue
  var p=sim.position(c.id)
  var flame=cylinder(0.18,0,0.8,Color("efaa4d"),Vector3(p.x,c.e+0.4,p.y),effects)
  fire_nodes.append(flame)
  if fire_nodes.size()>60: break
func animate(delta: float) -> void:
 animation_time+=delta
 if rain!=null: rain.emitting=(sim.weather=="Divine rainfall" or (sim.tick>=Sim.DAY*2 and sim.tick<Sim.DAY*3)) and not sim.paused
 if smoke!=null: smoke.speed_scale=0 if sim.paused else 1
 if not sim.paused:
  for i in birds.size():
   var t=animation_time*0.15+i*0.3
   birds[i].position=Vector3(-5+cos(t)*10,7+sin(t*2+i)*0.25,sin(t)*6)
   birds[i].rotation.y=-t
 for p in sim.people:
  if person_nodes.has(p.id) and not p.path.is_empty() and not sim.paused:
   person_nodes[p.id].position.y+=abs(sin(animation_time*8+p.id))*0.035
 for b in sim.buildings:
  if building_nodes.has(b.id) and building_nodes[b.id].has_node("Blades") and not sim.paused: building_nodes[b.id].get_node("Blades").rotation.z+=delta*0.7
 if globe_mode: globe.rotation.y+=delta*0.018 if not sim.paused else 0.0
func rebuild_globe() -> void:
 for child in globe.get_children(): child.free()
 var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in Sim.H-1:
  for x in Sim.W:
   var id=z*Sim.W+x; var col=cell_color(sim.cells[id])
   if sim.cells[id].e<0: col=Color("447e8b")
   for corner in [Vector2i(x,z),Vector2i(x+1,z+1),Vector2i(x+1,z),Vector2i(x,z),Vector2i(x,z+1),Vector2i(x+1,z+1)]:
    var lat=(float(corner.y)/Sim.H-0.5)*PI
    var lon=float(corner.x)/Sim.W*TAU
    var dir=Vector3(cos(lat)*sin(lon),sin(lat),cos(lat)*cos(lon))
    surface.set_color(col); surface.set_normal(dir); surface.add_vertex(dir*13.0)
 var mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 var mesh=surface.commit(); mesh.surface_set_material(0,mat)
 mesh_node(mesh,null,Vector3(0,3,0),globe)
func set_globe(enabled: bool) -> void:
 globe_mode=enabled; local_world.visible=not enabled; globe.visible=enabled
 if enabled: rebuild_globe()
func show_brush(x: float,z: float,radius: float) -> void:
 brush.visible=true; brush.position=Vector3(x,maxf(sim.elevation(x,z),sim.flood)+0.1,z); brush.scale=Vector3.ONE*radius/3
