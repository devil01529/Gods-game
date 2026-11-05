class_name WorldView
extends Node3D
const Sim=preload("res://scripts/simulation.gd")
var sim: WorldSimulation
var terrain: MeshInstance3D
var water: MeshInstance3D
var flood_mesh: MeshInstance3D
var scorch_mesh: MeshInstance3D
var last_hazard_draw=-10000
var last_ecology_draw=-10000
var vegetation=Node3D.new()
var structures=Node3D.new()
var citizens=Node3D.new()
var effects=Node3D.new()
var person_nodes={}
var building_nodes={}
var animal_nodes={}
var effect_nodes={}
var models={}
var material_cache={}
var ring: MeshInstance3D
var brush: MeshInstance3D
var globe_mode=false
var selected=-1
var overlay="Natural"
var animation_time=0.0
var fire_root=Node3D.new()
var fire_keys=[]
var smoke: CPUParticles3D
var last_terrain=-1
var last_ecology=-1
var last_fire_tick=-100
var focus=Vector2(-6,0)
var high_quality=true
var reduced_motion=false
var water_material: ShaderMaterial
var flood_material: ShaderMaterial
var flame_material: ShaderMaterial
var soft_texture: ImageTexture
var earthquake_shake=0.0
var planet_collision: CollisionShape3D
var rigid_debris: Array=[]

func mat(color: Color,unshaded: bool=false) -> StandardMaterial3D:
 var key=color.to_html()+str(unshaded)
 if material_cache.has(key):return material_cache[key]
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.85
 if unshaded:m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 if color.a<1:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.no_depth_test=false
 material_cache[key]=m;return m
func mesh_node(mesh: Mesh,material: Material,parent: Node3D,pos: Vector3=Vector3.ZERO) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;node.position=pos;parent.add_child(node);return node
func sphere(radius: float,color: Color,parent: Node3D,pos: Vector3=Vector3.ZERO) -> MeshInstance3D:
 var mesh=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=24;mesh.rings=12
 return mesh_node(mesh,mat(color),parent,pos)
func line(a: Vector3,b: Vector3,radius: float,color: Color,parent: Node3D) -> MeshInstance3D:
 var mesh=CylinderMesh.new();mesh.bottom_radius=radius;mesh.top_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=5
 var node=mesh_node(mesh,mat(color,true),parent,(a+b)*.5)
 if a.distance_to(b)>.001:node.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
 return node
func basis_at(x: float,z: float,yaw: float=0.0) -> Basis:
 var up=sim.normal_at(x,z);var east=Vector3(cos(x/Sim.RADIUS),0,-sin(x/Sim.RADIUS))
 return Basis(east,up,east.cross(up)).rotated(up,yaw)
func setup(state: WorldSimulation) -> void:
 sim=state;add_child(vegetation);add_child(structures);add_child(citizens);add_child(effects);effects.add_child(fire_root)
 for kind in ["home","storehouse","farm","well","levee","workshop","market","windmill","observatory","citizen_0","citizen_1","citizen_2","citizen_3","dog","cat","deer","boat","tree_0","tree_1","tree_2","tree_3"]:
  models[kind]=load("res://assets/models/"+kind+".glb")
 setup_shaders()
 var ground=StaticBody3D.new();ground.name="PlanetCollision";add_child(ground);planet_collision=CollisionShape3D.new();ground.add_child(planet_collision)
 var gravity=Area3D.new();gravity.name="RadialGravity";gravity.gravity_space_override=Area3D.SPACE_OVERRIDE_REPLACE;gravity.gravity_point=true;gravity.gravity_point_center=Vector3.ZERO;gravity.gravity_point_unit_distance=Sim.PLANET_RADIUS;gravity.gravity=9.8
 var field=CollisionShape3D.new();var volume=SphereShape3D.new();volume.radius=Sim.PLANET_RADIUS+35;field.shape=volume;gravity.add_child(field);add_child(gravity)
 terrain=MeshInstance3D.new();add_child(terrain)
 var ocean=SphereMesh.new();ocean.radius=Sim.PLANET_RADIUS+.015;ocean.height=(Sim.PLANET_RADIUS+.015)*2;ocean.radial_segments=192;ocean.rings=96
 water=mesh_node(ocean,water_material,self)
 flood_mesh=MeshInstance3D.new();add_child(flood_mesh);flood_mesh.material_override=flood_material
 scorch_mesh=MeshInstance3D.new();add_child(scorch_mesh)
 var soot=Shader.new();soot.code="shader_type spatial;render_mode cull_disabled,depth_draw_never;void fragment(){ALBEDO=vec3(.055,.044,.027);ROUGHNESS=1.0;ALPHA=smoothstep(.7,.35,length(UV-vec2(.5)))*.8;}"
 var soot_material=ShaderMaterial.new();soot_material.shader=soot;scorch_mesh.material_override=soot_material
 ring=make_ring(.62,Color("f6d48a"));add_child(ring);ring.visible=false
 brush=make_ring(3.0,Color("e6d6a0"));add_child(brush);brush.visible=false
 rebuild_terrain();rebuild_vegetation();make_atmosphere();make_paths();sync()
func setup_shaders() -> void:
 var shader=Shader.new()
 shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep_color: source_color = vec4(0.025,0.19,0.25,1.0);
varying vec3 sphere_pos;
void vertex(){sphere_pos=VERTEX;float w=sin(VERTEX.x*2.0+TIME*1.2)*sin(VERTEX.z*1.7-TIME*.8);VERTEX+=NORMAL*w*.013;}
void fragment(){float wave=sin(dot(sphere_pos,vec3(2.7,1.8,3.1))+TIME*1.4)*.5+sin(dot(sphere_pos,vec3(-3.1,2.2,1.3))-TIME*.8)*.3+sin(dot(sphere_pos,vec3(5.1,-3.2,2.3))+TIME*2.1)*.2;float fresnel=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.0);ALBEDO=mix(deep_color.rgb,vec3(.18,.56,.57),fresnel*.42)+wave*.009;ROUGHNESS=.19;METALLIC=.32;SPECULAR=.8;}
"""
 water_material=ShaderMaterial.new();water_material.shader=shader
 var flood_shader=Shader.new()
 var code=shader.code.replace("render_mode cull_disabled;","render_mode cull_disabled,depth_prepass_alpha;")
 code=code.replace("varying vec3 sphere_pos;","varying vec3 sphere_pos; varying float coverage; varying float wet_depth;")
 code=code.replace("sphere_pos=VERTEX;","sphere_pos=VERTEX;coverage=COLOR.a;wet_depth=COLOR.r;")
 code=code.replace("ROUGHNESS=.19;","ALBEDO=mix(vec3(.22,.47,.45),ALBEDO,smoothstep(.0,.45,wet_depth));ALPHA=coverage;ROUGHNESS=.19;")
 flood_shader.code=code;flood_material=ShaderMaterial.new();flood_material.shader=flood_shader
 var fs=Shader.new();fs.code="""shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
varying vec3 world_point;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;vec3 up=normalize(MODEL_MATRIX[1].xyz);vec3 look=normalize(CAMERA_POSITION_WORLD-MODEL_MATRIX[3].xyz);vec3 right=normalize(cross(up,look));vec3 forward=cross(right,up);MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(forward,0.0),MODEL_MATRIX[3]);}
void fragment(){float h=1.0-UV.y;float phase=world_point.x*.4+world_point.z*.3;float n=noise(vec2(UV.x*5.0+phase,h*6.0-TIME*3.5));n+=noise(vec2(UV.x*12.0-phase,h*15.0-TIME*6.0))*.35;float curl=sin(h*7.0-TIME*4.0+phase)*.06;float core=(1.0-h)*.58-abs(UV.x-.5+curl);float density=core+n*.19-h*.11;float a=smoothstep(.02,.17,density)*smoothstep(1.0,.7,h)*smoothstep(0.0,.06,h);vec3 col=mix(vec3(.92,.11,.005),vec3(1.0,.64,.08),clamp(density*3.0,0.0,1.0));col=mix(col,vec3(1.0,.96,.62),clamp(density*4.0-.8,0.0,1.0));ALBEDO=col;EMISSION=col*.6;ALPHA=a*.9;}
"""
 flame_material=ShaderMaterial.new();flame_material.shader=fs
 var image=Image.create(32,32,false,Image.FORMAT_RGBA8)
 for y in 32:
  for x in 32:
   var d=Vector2(x-15.5,y-15.5).length()/15.5;image.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-d),1.5)))
 soft_texture=ImageTexture.create_from_image(image)
func make_ring(radius: float,color: Color) -> MeshInstance3D:
 var mesh=TorusMesh.new();mesh.inner_radius=radius-.035;mesh.outer_radius=radius+.035;mesh.rings=48;mesh.ring_segments=5
 var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat(color,true);return node
func color_for(c: Dictionary) -> Color:
 if overlay=="Danger":return Color("a64f38") if c.fire>0 or c.water>.5 or c.electric>sim.tick else Color("487d65")
 if overlay=="Climate":return Color("b88d4f").lerp(Color("457c8a"),clampf(c.e/4,0,1))
 if c.ice:return Color("d4e6e3")
 if c.e<0:return Color("27626a")
 if c.e<.20:return Color("a69c6c")
 if c.ash>.1:return Color("5e674b").lerp(Color("393a32"),c.ash)
 var p=sim.position(c.id);var variation=sin(p.x*.33)*cos(p.y*.26)*.025
 if c.e>2:return Color("72836b")
 return Color(.52+variation,.62+variation,.39+variation)
func corner_height(x: int,z: int) -> float:
 var h=0.0
 for dz in [-1,0]:
  for dx in [-1,0]:h+=sim.cells[clampi(z+dz,0,Sim.H-1)*Sim.W+posmod(x+dx,Sim.W)].e
 return h*.25
func rebuild_terrain() -> void:
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array();var uvs=PackedVector2Array()
 for z in Sim.H+1:
  for x in Sim.W+1:
   var px=(x-Sim.W/2)*Sim.CELL-Sim.CELL*.5;var pz=clampf((z-Sim.H/2)*Sim.CELL-Sim.CELL*.5,-Sim.H*.5,Sim.H*.5)
   var normal=sim.normal_at(px,pz);var color=Color(0,0,0,0)
   for dz in [-1,0]:
    for dx in [-1,0]:color+=color_for(sim.cells[clampi(z+dz,0,Sim.H-1)*Sim.W+posmod(x+dx,Sim.W)])*.25
   vertices.append(normal*(Sim.PLANET_RADIUS+corner_height(x,z)));normals.append(normal);colors.append(color);uvs.append(Vector2(px,pz)*.20)
 for z in Sim.H:
  for x in Sim.W:
   var a=z*(Sim.W+1)+x;var b=a+1;var c=b+Sim.W+1;var d=c-1
   for i in [a,b,c,a,c,d]:indices.append(i)
 var pole=vertices.size();vertices.append(Vector3.UP*(Sim.PLANET_RADIUS+.14));normals.append(Vector3.UP);colors.append(Color("d4e6e3"));uvs.append(Vector2.ZERO)
 for x in Sim.W:
  for i in [Sim.H*(Sim.W+1)+x,Sim.H*(Sim.W+1)+x+1,pole]:indices.append(i)
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_TEX_UV]=uvs
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=1;material.albedo_texture=load("res://assets/textures/meadow.png");material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 terrain.mesh=mesh;terrain.material_override=material;last_terrain=sim.terrain_revision
 if planet_collision!=null:
  var shape=mesh.create_trimesh_shape();shape.backface_collision=true;planet_collision.shape=shape
func make_paths() -> void:
 var vertices=PackedVector3Array();var normals=PackedVector3Array()
 for route in [[Vector2(-11,1),Vector2(-6,0),Vector2(-3,5)],[Vector2(-8,-5),Vector2(-6,0),Vector2(-3,-5)]]:
  for segment in route.size()-1:
   var a=route[segment];var b=route[segment+1];var normal=(b-a).normalized().orthogonal()*.20
   for i in 20:
    var start=a.lerp(b,float(i)/20);var end=a.lerp(b,float(i+1)/20)
    for point in [start-normal,start+normal,end+normal,start-normal,end+normal,end-normal]:
     vertices.append(sim.surface(point.x,point.y,.035));normals.append(sim.normal_at(point.x,point.y))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);var material=mat(Color("9d8967"));material.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh_node(mesh,material,structures)
func _model_mesh(kind: String) -> Mesh:
 var instance=models[kind].instantiate();var found: Mesh=null
 for child in instance.get_children():
  if child is MeshInstance3D:found=child.mesh;break
 instance.free();return found
func rebuild_vegetation() -> void:
 for child in vegetation.get_children():child.free()
 var transforms=[[],[],[],[]]
 for c in sim.cells:
  if not c.forest or c.id%5!=0 or c.e<.15 or c.ice:continue
  var p=sim.position(c.id)
  p+=Vector2(sin(c.id*3.71),cos(c.id*2.91))*.3
  var occupied=false
  for b in sim.buildings:
   if sim.distance(p,Vector2(b.x,b.z))<2.8:occupied=true;break
  if sim.distance(p,Vector2(-6,0))<5:occupied=true
  if occupied:continue
  var size=.78+absf(sin(c.id*1.6))*.48;var variant=int(c.id/5)%4
  transforms[variant].append(Transform3D(basis_at(p.x,p.y,c.id*.13).scaled(Vector3.ONE*size),sim.surface(p.x,p.y)))
 for i in 4:
  var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=_model_mesh("tree_"+str(i));multi.instance_count=transforms[i].size()
  for j in transforms[i].size():multi.set_instance_transform(j,transforms[i][j])
  var node=MultiMeshInstance3D.new();node.multimesh=multi;vegetation.add_child(node)
 var grass_mesh=ArrayMesh.new();var gv=PackedVector3Array();var gn=PackedVector3Array()
 for a in [0.0,PI/3,PI*2/3]:
  var side=Vector3(cos(a)*.07,0,sin(a)*.07)
  for v in [-side,side,Vector3(.035,.22,.015)]:gv.append(v);gn.append(Vector3.UP)
 var ga=[];ga.resize(Mesh.ARRAY_MAX);ga[Mesh.ARRAY_VERTEX]=gv;ga[Mesh.ARRAY_NORMAL]=gn;grass_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,ga)
 var gm=mat(Color("7e9951"));gm.cull_mode=BaseMaterial3D.CULL_DISABLED;grass_mesh.surface_set_material(0,gm)
 var transforms_grass=[]
 for c in sim.cells:
  if c.id%3!=0 or c.e<.2 or c.ice:continue
  var p=sim.position(c.id)+Vector2(sin(c.id*3),cos(c.id*5))*.3
  transforms_grass.append(Transform3D(basis_at(p.x,p.y,c.id),sim.surface(p.x,p.y,.01)))
 var grass=MultiMesh.new();grass.transform_format=MultiMesh.TRANSFORM_3D;grass.mesh=grass_mesh;grass.instance_count=transforms_grass.size()
 for i in transforms_grass.size():grass.set_instance_transform(i,transforms_grass[i])
 var grass_node=MultiMeshInstance3D.new();grass_node.multimesh=grass;grass_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;vegetation.add_child(grass_node)
 last_ecology=sim.ecology_revision
func make_atmosphere() -> void:
 var mesh=SphereMesh.new();mesh.radius=Sim.PLANET_RADIUS+1.0;mesh.height=(Sim.PLANET_RADIUS+1.0)*2;mesh.radial_segments=96;mesh.rings=48
 var shader=Shader.new();shader.code="""shader_type spatial;render_mode unshaded,blend_add,cull_front,depth_draw_never,shadows_disabled;void fragment(){float limb=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.5);ALBEDO=vec3(.12,.42,.64);ALPHA=limb*.35;}"""
 var material=ShaderMaterial.new();material.shader=shader;mesh_node(mesh,material,self)
 # Clouds are actual meshes around the same sphere, not a flat map backdrop.
 for i in 18:
  var x=wrapf(i*37.13+33,-128,128);var z=sin(i*2.17)*45
  if sim.distance(Vector2(x,z),Vector2(-6,0))<24:continue
  var cloud=Node3D.new();add_child(cloud);cloud.position=sim.normal_at(x,z)*(Sim.PLANET_RADIUS+3.8);cloud.basis=basis_at(x,z)
  for j in 4:
   var puff=sphere(1.0,Color(.82,.91,.94,.72),cloud,Vector3(j*1.1-1.5,.1*sin(j),0));puff.scale=Vector3(1.4,.38,.8);puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func instantiate_model(kind: String,parent: Node3D) -> Node3D:
 var node=models[kind].instantiate();parent.add_child(node);return node
func make_person(p: Dictionary) -> Node3D:
 var node=Node3D.new();citizens.add_child(node);var model=instantiate_model("citizen_"+str(int(p.id)%4),node);model.name="Model"
 var boat=instantiate_model("boat",node);boat.name="Boat";boat.visible=false
 person_nodes[p.id]={"node":node,"model":model,"last":Vector2(p.x,p.z),"phase":0.0,"desired":sim.surface(p.x,p.z,.035),"yaw":0.0}
 node.position=sim.surface(p.x,p.z,.035);node.basis=basis_at(p.x,p.z)
 return node
func sync() -> void:
 if sim.terrain_revision!=last_terrain:rebuild_terrain()
 if sim.ecology_revision!=last_ecology and Time.get_ticks_msec()-last_ecology_draw>1500:rebuild_vegetation();last_ecology_draw=Time.get_ticks_msec()
 for p in sim.people:
  if not person_nodes.has(p.id):make_person(p)
  var data=person_nodes[p.id];var delta=sim.wrapped_delta(data.last,Vector2(p.x,p.z))
  data.phase+=delta.length()*7
  if delta.length()>.005:data.yaw=atan2(delta.x,-delta.y)
  data.last=Vector2(p.x,p.z);data.desired=sim.surface(p.x,p.z,.035)
  data.node.get_node("Boat").visible=p.alive and sim.traded and sim.cells[sim.cell_at(p.x,p.z)].water>.55
  var depth=sim.cells[sim.cell_at(p.x,p.z)].water
  if depth>.55 and p.alive and sim.traded:data.desired=sim.normal_at(p.x,p.z)*(sim.water_radius(sim.cells[sim.cell_at(p.x,p.z)])+.16)
 for b in sim.buildings:
  if not building_nodes.has(b.id):
   building_nodes[b.id]=instantiate_model(b.kind,structures)
   if b.kind in ["home","storehouse","workshop","market","windmill","observatory"]:
    var solid=StaticBody3D.new();var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(1.7 if b.kind=="home" else 2.5,1.5,1.5 if b.kind=="home" else 2.0);collider.shape=shape;collider.position.y=.75;solid.add_child(collider);building_nodes[b.id].add_child(solid)
  var node=building_nodes[b.id];node.position=sim.surface(b.x,b.z,.015);node.basis=basis_at(b.x,b.z)
  var stage=1.0 if b.complete else maxf(.08,b.work/WorldRules.BUILDINGS[b.kind].work)
  node.scale=Vector3(1,stage,1)
  if b.health<=0:node.scale=Vector3(1,.25,1);node.rotate_object_local(Vector3.FORWARD,.15)
 for id in building_nodes.keys():
  var found=false
  for b in sim.buildings:
   if b.id==id:found=true
  if not found:building_nodes[id].queue_free();building_nodes.erase(id)
 for a in sim.animals:
  if not animal_nodes.has(a.id):animal_nodes[a.id]={"node":instantiate_model(a.species,citizens),"last":Vector2(a.x,a.z),"yaw":0.0}
  var d=animal_nodes[a.id];var delta=sim.wrapped_delta(d.last,Vector2(a.x,a.z))
  if delta.length()>.005:d.yaw=atan2(delta.x,-delta.y)
  d.last=Vector2(a.x,a.z)
  d.node.position=sim.surface(a.x,a.z,.025);d.node.basis=basis_at(a.x,a.z,d.yaw)
  if not a.alive:d.node.rotate_object_local(Vector3.FORWARD,PI/2)
 var p=sim.person(selected);ring.visible=not p.is_empty()
 if ring.visible:ring.position=sim.surface(p.x,p.z,.09);ring.basis=basis_at(p.x,p.z)
 if Time.get_ticks_msec()-last_hazard_draw>=150:update_hazards();last_hazard_draw=Time.get_ticks_msec()
 update_disasters()
func animate(delta: float) -> void:
 animation_time+=delta
 for body in rigid_debris:
  if is_instance_valid(body):body.freeze=sim.paused
 for p in sim.people:
  if not person_nodes.has(p.id):continue
  var d=person_nodes[p.id];var node: Node3D=d.node
  node.position=node.position.lerp(d.desired,1.0-exp(-delta*18));node.basis=basis_at(p.x,p.z,d.yaw)
  var scale=.58 if p.age<16 else 1.0;d.model.scale=Vector3.ONE*scale
  if not p.alive:node.rotate_object_local(Vector3.FORWARD,PI/2);continue
  var walking=not p.path.is_empty() and not sim.paused
  for part_name in ["LegL","LegR","ArmL","ArmR"]:
   var part=d.model.find_child(part_name,true,false)
   if part!=null:part.rotation.x=sin(d.phase)*(.55 if part_name in ["LegL","ArmR"] else -.55) if walking else 0.0
  if p.task in ["gather","build","harvest"] and not walking and not sim.paused:
   var arm=d.model.find_child("ArmR",true,false)
   if arm!=null:arm.rotation.x=-.7+sin(animation_time*6)*.4
 for flame in fire_root.get_children():
  if flame.has_meta("flame"):flame.scale.y=1.0+sin(animation_time*9+float(flame.get_meta("flame")))*.15
 for key in effect_nodes:
  var data=effect_nodes[key];var d=data.disaster;var node=data.node
  if d.kind=="tornado":
   for i in node.get_child_count():
    var part=node.get_child(i)
    if part is MeshInstance3D:part.rotation.y=animation_time*(2.0+i*.1)
  if d.kind=="meteor":
   var rock=node.get_node_or_null("Meteor")
   if rock!=null:rock.position.y=maxf(.3,15.0-(sim.tick-d.start)*Sim.DT*22)
  if d.kind=="lightning":node.visible=fmod(animation_time,.14)<.095
 earthquake_shake=0.0
 if not reduced_motion:
  for d in sim.disasters:
   if d.kind=="quake" and sim.tick-d.start<40:earthquake_shake=.08*sin(animation_time*45)
func update_hazards() -> void:
 for child in fire_root.get_children():child.queue_free()
 var visible_fire=[];var candidates={};var soot_vertices=PackedVector3Array();var soot_normals=PackedVector3Array();var soot_uvs=PackedVector2Array()
 for id in sim.active_cells:
  var c=sim.cells[id];var p=sim.position(id)
  if c.ash>.05:
   for corner in [Vector2(-.75,-.75),Vector2(.75,-.75),Vector2(.75,.75),Vector2(-.75,-.75),Vector2(.75,.75),Vector2(-.75,.75)]:
    var n=sim.normal_at(p.x+corner.x,p.y+corner.y);soot_vertices.append(n*(Sim.PLANET_RADIUS+c.e+.025));soot_normals.append(n);soot_uvs.append(corner/1.5+Vector2(.5,.5))
  if c.water>maxf(0,-c.e)+.015:
   for dz in [-1,0,1]:
    for dx in [-1,0,1]:
     var row=clampi(int(id)/Sim.W+dz,0,Sim.H-1);candidates[row*Sim.W+posmod(int(id)%Sim.W+dx,Sim.W)]=true
  if c.fire>0 and sim.distance(p,focus)<25:visible_fire.append(id)
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array();var corner_ids={}
 for id in candidates:
  var x=int(id)%Sim.W;var z=int(id)/Sim.W;var corners=[]
  for coord in [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]:
   if not corner_ids.has(coord):
    var level=0.0;var depth=0.0
    for dz in [-1,0]:
     for dx in [-1,0]:
      var c=sim.cells[clampi(coord.y+dz,0,Sim.H-1)*Sim.W+posmod(coord.x+dx,Sim.W)]
      level+=(c.e+c.water)*.25;depth+=c.water*.25
    var px=(coord.x-Sim.W/2)*Sim.CELL-.5;var pz=clampf((coord.y-Sim.H/2)*Sim.CELL-.5,-64,64);var n=sim.normal_at(px,pz)
    corner_ids[coord]=vertices.size();vertices.append(n*(Sim.PLANET_RADIUS+level+.025));normals.append(n);colors.append(Color(clampf(depth/1.5,0,1),1,1,smoothstep(.015,.15,depth)))
   corners.append(corner_ids[coord])
  for index in [0,1,2,0,2,3]:indices.append(corners[index])
 if not vertices.is_empty():
  var a=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=vertices;a[Mesh.ARRAY_NORMAL]=normals;a[Mesh.ARRAY_COLOR]=colors;a[Mesh.ARRAY_INDEX]=indices
  var m=ArrayMesh.new();m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);flood_mesh.mesh=m
 else:flood_mesh.mesh=null
 if not soot_vertices.is_empty():
  var a=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=soot_vertices;a[Mesh.ARRAY_NORMAL]=soot_normals;a[Mesh.ARRAY_TEX_UV]=soot_uvs
  var m=ArrayMesh.new();m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);scorch_mesh.mesh=m
 else:scorch_mesh.mesh=null
 visible_fire.sort_custom(func(a,b):return sim.distance(sim.position(a),focus)<sim.distance(sim.position(b),focus))
 var limit=mini(visible_fire.size(),38 if high_quality else 18)
 for i in limit:
  var id=visible_fire[i];var p=sim.position(id);var node=Node3D.new();fire_root.add_child(node);node.position=sim.surface(p.x,p.y,.04);node.basis=basis_at(p.x,p.y)
  node.set_meta("flame",i)
  node.position+=node.basis.x*sin(id*5.7)*.30+node.basis.z*cos(id*3.1)*.30
  node.scale*=.65+absf(sin(id*7.7))*.65
  for layer in 2:
   var quad=QuadMesh.new();quad.size=Vector2(3.0 if layer==0 else 2.2,2.4 if layer==0 else 1.9)
   var flame=mesh_node(quad,flame_material,node,Vector3(.3*layer,1.0 if layer==0 else .75,.16*layer));flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  if i<2 and high_quality:
   var light=OmniLight3D.new();node.add_child(light);light.position=Vector3(0,.8,0);light.light_color=Color("ff9c3d");light.light_energy=2;light.omni_range=4
 if smoke==null:
  smoke=make_smoke(Vector3.ZERO,Vector3.UP,effects,60 if high_quality else 25)
 smoke.emitting=limit>0
 if limit>0:
  var p=sim.position(visible_fire[0]);smoke.position=sim.surface(p.x,p.y,1);smoke.direction=sim.normal_at(p.x,p.y);smoke.gravity=sim.normal_at(p.x,p.y)*.15
func make_smoke(pos: Vector3,up: Vector3,parent: Node3D,count: int=40) -> CPUParticles3D:
 var particles=CPUParticles3D.new();parent.add_child(particles);particles.position=pos;particles.amount=count;particles.lifetime=5;particles.preprocess=1.0;particles.direction=up;particles.spread=35;particles.gravity=up*.15+Vector3(.12*sim.wind,0,0);particles.initial_velocity_min=1.1;particles.initial_velocity_max=2.2;particles.scale_amount_min=.4;particles.scale_amount_max=1.8
 var quad=QuadMesh.new();quad.size=Vector2(1.1,1.1)
 var material=StandardMaterial3D.new();material.albedo_color=Color(.19,.22,.22,.5);material.albedo_texture=soft_texture;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;quad.material=material;particles.mesh=quad;particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return particles
func update_disasters() -> void:
 var live={}
 for d in sim.disasters:
  var key=d.kind+str(d.start)+str(d.x);live[key]=true
  if effect_nodes.has(key):continue
  var node=Node3D.new();effects.add_child(node);node.position=sim.surface(d.x,d.z);node.basis=basis_at(d.x,d.z).scaled(Vector3.ONE*(Sim.PLANET_RADIUS/Sim.RADIUS))
  effect_nodes[key]={"node":node,"disaster":d}
  if d.kind in ["quake","meteor"]:make_debris(d,node)
  match d.kind:
   "rain","flood":
    var cloud=sphere(1.0,Color(.25,.32,.36,.85),node,Vector3(0,8,0));cloud.scale=Vector3(d.radius*.8,1.0,d.radius*.7)
    var rain=CPUParticles3D.new();node.add_child(rain);rain.position=Vector3(0,7,0);rain.amount=250 if high_quality else 100;rain.lifetime=.9;rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;rain.emission_box_extents=Vector3(d.radius,0,d.radius);rain.direction=Vector3.DOWN;rain.initial_velocity_min=8;rain.initial_velocity_max=12;rain.gravity=Vector3(0,-3,0)
    var mesh=BoxMesh.new();mesh.size=Vector3(.014,.30,.014);mesh.material=mat(Color("b1d2dc"),true);rain.mesh=mesh;rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   "lightning":
    var point=Vector3(0,11,0)
    for i in 9:
     var next=Vector3(sin(i*3.7)*.45,11-(i+1)*1.2,cos(i*4.3)*.3)
     line(point,next,.035,Color("d8f7ff"),node);point=next
    var light=OmniLight3D.new();light.light_color=Color("a8ddff");light.light_energy=4;light.omni_range=9;light.position=Vector3(0,1,0);node.add_child(light)
    for id in sim.active_cells:
     var c=sim.cells[id]
     if c.electric>sim.tick:
      var p=sim.position(id)
      var arc=make_ring(.4,Color("a2e6ff"));effects.add_child(arc);arc.position=sim.normal_at(p.x,p.y)*(sim.water_radius(c)+.06);arc.basis=basis_at(p.x,p.y);node.tree_exiting.connect(arc.queue_free)
   "tornado":
    var funnel=CylinderMesh.new();funnel.bottom_radius=.18;funnel.top_radius=1.9;funnel.height=6;funnel.radial_segments=48;funnel.rings=12
    var shader=Shader.new();shader.code="shader_type spatial;render_mode cull_disabled,depth_draw_never,shadows_disabled;void vertex(){VERTEX.x+=sin(VERTEX.y*1.3+TIME)*.09;VERTEX.z+=cos(VERTEX.y+TIME)*.09;}void fragment(){float bands=sin(UV.y*76.0+UV.x*23.0-TIME*7.0)*.5+.5;float wisps=sin(UV.x*82.0+UV.y*21.0-TIME*2.0)*.5+.5;ALBEDO=vec3(.34,.38,.39)+bands*.10;ROUGHNESS=1.0;ALPHA=.24+bands*.25+wisps*.12;}"
    var material=ShaderMaterial.new();material.shader=shader;mesh_node(funnel,material,node,Vector3(0,3,0))
    for i in 5:
     var mesh=TorusMesh.new();var radius=.25+i*.31;mesh.inner_radius=radius*.88;mesh.outer_radius=radius;mesh.rings=32;mesh.ring_segments=5
     mesh_node(mesh,mat(Color(.42,.45,.45,.25)),node,Vector3(sin(i)*.08,i*1.12+.3,0))
    make_smoke(Vector3.ZERO,Vector3.UP,node,70)
   "quake":
    for i in 5:
     var a=Vector3.ZERO
     for j in 5:
      var b=Vector3((j+1)*.65*cos(i*TAU/5)+sin(j*3)*.3,.03,(j+1)*.65*sin(i*TAU/5))
      line(a,b,.035,Color("302f27"),node);a=b
    for i in 12:
     var rock=sphere(.15,Color("6e7667"),node,Vector3(sin(i*3.2)*3,.15,cos(i*2.3)*3));rock.scale.y=.7
   "meteor":
    var meteor=sphere(.65,Color("6b4d39"),node,Vector3(0,15,0));meteor.name="Meteor";make_smoke(Vector3.ZERO,Vector3.UP,node,45)
   "shield":
    var dome=sphere(d.radius,Color(.72,.82,.45,.12),node)
    dome.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for key in effect_nodes.keys():
  if not live.has(key):effect_nodes[key].node.queue_free();effect_nodes.erase(key)
func show_brush(x: float,z: float,radius: float) -> void:
 brush.visible=true;brush.position=sim.surface(x,z,.10);brush.basis=basis_at(x,z);brush.scale=Vector3.ONE*radius/3.0*(Sim.PLANET_RADIUS/Sim.RADIUS)
func set_globe(enabled: bool) -> void:globe_mode=enabled
func rebuild_globe() -> void:rebuild_terrain()

func make_debris(d: Dictionary,parent: Node3D) -> void:
 var up=sim.normal_at(d.x,d.z);var east=Vector3(cos(d.x/Sim.RADIUS),0,-sin(d.x/Sim.RADIUS));var north=up.cross(east)
 for i in (14 if high_quality else 6):
  var body=RigidBody3D.new();effects.add_child(body);body.mass=.3;body.freeze=sim.paused
  var angle=i*2.399;var side=east*cos(angle)+north*sin(angle)
  body.position=sim.surface(d.x,d.z,.6)+side*(.5+float(i%4)*.4)
  var collider=CollisionShape3D.new();var shape=SphereShape3D.new();shape.radius=.12;collider.shape=shape;body.add_child(collider)
  var mesh=SphereMesh.new();mesh.radius=.13;mesh.height=.26;mesh.radial_segments=6;mesh.rings=3;mesh_node(mesh,mat(Color("78786a")),body)
  body.linear_velocity=up*(3.0+float(i%3))+side*(1.0+float(i%4)*.4);body.angular_velocity=Vector3(i*.13,2,i*.21);rigid_debris.append(body)
  parent.tree_exiting.connect(body.queue_free)
