"""Original Worldkeeper meshes. Run with Blender 4.x: blender -b -t 2 -P tools/create_models.py."""
import bpy, math, random
from mathutils import Vector
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'assets/models'; OUT.mkdir(exist_ok=True)
random.seed(24017)
PALETTE={'wood':(.29,.15,.075,1),'oak':(.49,.30,.14,1),'plank':(.63,.44,.23,1),'stone':(.43,.49,.49,1),'wall':(.78,.71,.53,1),'roof':(.21,.31,.29,1),'tile':(.30,.43,.39,1),'metal':(.27,.32,.34,1),'glass':(.28,.63,.67,1),'dark':(.075,.11,.10,1),'gold':(.95,.68,.24,1),'leaf':(.14,.33,.20,1),'leaf2':(.29,.47,.24,1),'grass':(.56,.63,.26,1),'skin':(.65,.40,.23,1),'hair':(.13,.075,.045,1),'cream':(.89,.80,.59,1),'clay':(.60,.27,.15,1)}
materials={}
for name,color in PALETTE.items():
 m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=.78
 if name=='metal':bs.inputs['Metallic'].default_value=.7
 materials[name]=m

def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(obj,name):obj.data.materials.append(materials[name]);return obj
def box(name,pos,size,m='wood',bevel=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Crafted edges','BEVEL');mod.width=bevel;mod.segments=1
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return mat(o,m)
def ellipsoid(name,pos,size,m='leaf',sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 return mat(o,m)
def cyl(name,pos,r,depth,m='wood',vertices=10,r2=None):
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=depth,location=pos);o=bpy.context.object;o.name=name;return mat(o,m)
def beam(a,b,r=.05,m='wood'):
 mid=(Vector(a)+Vector(b))*.5;delta=Vector(b)-Vector(a);o=cyl('beam',mid,r,delta.length,m,8);o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();return o

def export(name,articulated=False):
 # Bake color to vertices and merge static parts: one draw surface per mesh.
 vertexmat=bpy.data.materials.get('Worldkeeper vertex paint')
 if vertexmat is None:
  vertexmat=bpy.data.materials.new('Worldkeeper vertex paint');vertexmat.use_nodes=True
  nodes=vertexmat.node_tree.nodes;vc=nodes.new('ShaderNodeVertexColor');vc.layer_name='Col';bs=nodes.get('Principled BSDF');vertexmat.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=.83
 groups={}
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH':continue
  color=obj.data.materials[0].diffuse_color if obj.data.materials else (.5,.5,.5,1)
  attr=obj.data.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='CORNER')
  for item in attr.data:item.color=color
  obj.data.materials.clear();obj.data.materials.append(vertexmat)
  group=obj.get('part','Body') if articulated else 'Model'
  groups.setdefault(group,[]).append(obj)
 for group,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=group
  if articulated and group!='Body':
   origin={'LegL':(-.105,0,.46),'LegR':(.105,0,.46),'ArmL':(-.22,0,.83),'ArmR':(.22,0,.83),'Tail':(0,.40,.4)}.get(group,(0,0,0))
  else:origin=(0,0,0)
  bpy.context.scene.cursor.location=origin;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_animations=False,export_materials='EXPORT')
 print('MODEL',name)

for variant in range(4):
 reset();shirt=['roof','clay','glass','leaf'][variant]
 ellipsoid('Coat',(0,0,.67),(.22,.135,.30),shirt,2)
 box('Belt',(0,-.025,.53),(.38,.26,.055),'wood',.01)
 box('Buckle',(0,-.163,.53),(.07,.025,.065),'gold',.005)
 ellipsoid('Head',(0,-.005,1.04),(.155,.135,.19),'skin',2)
 ellipsoid('Hair',(0,.018,1.14),(.16,.14,.12),'hair',2)
 ellipsoid('Nose',(0,-.14,1.04),(.035,.045,.042),'skin')
 for x in [-.062,.062]:ellipsoid('Eye',(x,-.13,1.078),(.019,.014,.018),'dark',1)
 if variant%2==0:
  cyl('Hat brim',(0,.01,1.2),.23,.035,'plank',16);cyl('Hat crown',(0,.01,1.255),.14,.10,'plank',12,.11)
 else:ellipsoid('Hair braid',(.11,.08,.95),(.07,.09,.22),'hair',2)
 for side,label in [(-1,'L'),(1,'R')]:
  for obj in [box('Trousers',(side*.105,0,.30),(.15,.17,.36),'roof',.035),box('Leather boot',(side*.105,-.035,.07),(.17,.26,.14),'wood',.025)]:obj['part']='Leg'+label
  for obj in [ellipsoid('Sleeve',(side*.24,0,.72),(.09,.10,.20),shirt,2),ellipsoid('Hand',(side*.255,-.015,.50),(.065,.065,.08),'skin',2)]:obj['part']='Arm'+label
 export('citizen_'+str(variant),True)

for kind in ['home','storehouse','workshop','market','windmill','observatory','well','farm','levee']:
 reset()
 if kind=='farm':
  box('Rich soil',(0,0,.025),(2.9,2.5,.05),'wood',0)
  for i in range(7):
   for j in range(6):
    x=-1.15+i*.38;y=-1+j*.4
    beam((x,y,.04),(x,y,.42),.014,'grass')
    ellipsoid('Grain',(x+.025,y,.36),(.045,.035,.12),'gold')
  for x in [-1.5,1.5]:
   for y in [-1.3,0,1.3]:box('Fence post',(x,y,.32),(.08,.08,.64),'oak')
   box('Fence rail',(x,0,.45),(.055,2.7,.06),'plank')
 elif kind=='well':
  for i in range(12):
   a=i*math.tau/12;o=box('Well stone',(.53*math.cos(a),.53*math.sin(a),.26),(.27,.22,.48),'stone');o.rotation_euler.z=a
  cyl('Water',(0,0,.17),.43,.025,'glass',24)
  for x in [-.6,.6]:box('Pillar',(x,0,.8),(.09,.09,1.6),'oak')
  box('Beam',(0,0,1.52),(1.4,.15,.15),'plank')
  beam((0,0,1.52),(0,0,.4),.015,'cream')
  cyl('Bucket',(.15,0,.62),.12,.18,'oak',12)
 elif kind=='levee':
  for i in range(7):
   for j in range(2):box('Masonry',(-1.5+i*.5+j*.1,0,.16+j*.3),(.49,.7,.29),'stone',.025)
 elif kind=='observatory':
  cyl('Foundation',(0,0,.15),1.3,.3,'stone',24)
  cyl('Observatory tower',(0,0,1.1),1.0,1.9,'wall',24,.95)
  ellipsoid('Copper dome',(0,0,2.05),(.98,.98,.72),'glass',3)
  beam((0,0,2.15),(.9,-.9,3.0),.20,'metal')
  for i in range(8):
   a=i*math.tau/8;box('Window',(.96*math.cos(a),.96*math.sin(a),1.4),(.16,.16,.35),'glass')
 else:
  w=1.7 if kind=='home' else 2.5;d=1.5 if kind=='home' else 2.0
  box('Stone footings',(0,0,.12),(w+.18,d+.18,.24),'stone')
  box('Plaster walls',(0,0,.78),(w,d,1.35),'wall')
  for x in [-w*.48,w*.48]:
   for y in [-d*.48,d*.48]:box('Timber post',(x,y,.82),(.10,.10,1.50),'wood')
  box('Lintel',(0,-d*.51,1.33),(w,.10,.10),'wood')
  box('Front door',(0,-d*.51,.62),(.46,.07,1.04),'oak')
  for x in [-w*.32,w*.32]:
   box('Window frame',(x,-d*.515,.93),(.36,.08,.42),'wood')
   box('Window glass',(x,-d*.55,.93),(.27,.018,.32),'glass')
   box('Mullion',(x,-d*.56,.93),(.035,.02,.34),'cream')
  for side in [-1,1]:
   for row in range(5):
    y=side*(.13+row*.22);z=2.0-row*.13
    for j in range(7):
     o=box('Overlapping roof shingle',(-w*.56+j*w*.19,y,z),(w*.20,.30,.065),'roof' if (row+j)%3 else 'tile',.01);o.rotation_euler.x=side*-.53
  box('Roof ridge',(0,0,2.06),(w*1.28,.14,.13),'wood')
  if kind in ['storehouse','workshop','market']:
   for i in range(4):
    x=w*.65;y=-.6+i*.38
    box('Crate',(x,y,.27),(.40,.34,.48),'plank')
    for dz in [.1,.4]:box('Crate strap',(x,y,.02+dz),(.43,.37,.035),'wood')
   for i in range(3):ellipsoid('Grain sack',(-w*.65,-.5+i*.45,.26),(.27,.2,.3),'cream',2)
  if kind=='workshop':
   box('Chimney',(w*.26,d*.25,1.9),(.28,.3,1.4),'stone')
   beam((-1,-1.4,.6),(1,-1.4,.6),.07,'oak')
  if kind=='market':
   for x in [-1.6,1.6]:box('Awning support',(x,-1.6,.8),(.09,.09,1.6),'oak')
   box('Canvas awning',(0,-1.4,1.62),(3.4,1.25,.09),'clay')
   box('Trade counter',(0,-1.5,.62),(2.9,.65,.12),'oak')
  if kind=='windmill':
   cyl('Tower',(0,0,2.3),.45,3.6,'wall',12,.26)
   for i in range(4):
    a=i*math.tau/4
    beam((0,-.4,3.7),(math.sin(a)*1.6,-.4,3.7+math.cos(a)*1.6),.055,'oak')
    o=box('Sail',(math.sin(a)*1.0,-.4,3.7+math.cos(a)*1.0),(.27,.05,1.1),'cream');o.rotation_euler.y=a
 export(kind)

for variant in range(4):
 reset()
 h=2.8+variant*.4
 cyl('Trunk',(0,0,h*.3),.14,h*.6,'wood',9,.07)
 if variant<2:
  for j in range(7):
   a=j*2.4; x=math.cos(a)*.6;y=math.sin(a)*.6;z=h*.6+j*.13
   beam((0,0,h*.4),(x,y,z),.045,'wood');ellipsoid('Leaf crown',(x,y,z),(.75,.65,.65),'leaf' if j%2 else 'leaf2',2 if variant else 1)
 else:
  for j in range(4):cyl('Pine needles',(0,0,h*.4+j*h*.17),.9-j*.16,h*.65,'leaf' if j%2 else 'leaf2',10,.025)
 export('tree_'+str(variant))
for species in ['dog','cat','deer']:
 reset();m='oak' if species!='cat' else 'cream';scale=1.7 if species=='deer' else .7 if species=='cat' else 1
 ellipsoid('Body',(0,0,.37),(.17,.36,.20),m,2)
 ellipsoid('Neck',(0,-.28,.50),(.12,.13,.20),m,2)
 ellipsoid('Head',(0,-.38,.66),(.14,.17,.14),m,2)
 ellipsoid('Muzzle',(0,-.51,.62),(.10,.10,.075),'cream',1)
 ellipsoid('Nose',(0,-.59,.64),(.04,.025,.035),'dark')
 for side in [-1,1]:
  ellipsoid('Eye',(side*.11,-.46,.70),(.019,.018,.02),'dark')
  ear=cyl('Ear',(side*.11,-.35,.83),.085,.20,m,4,.005);ear.rotation_euler.y=side*.2
  for y in [-.22,.23]:
   leg=box('Leg',(side*.12,y,.18),(.075,.075,.36),m,.02);leg['part']='Leg'+('L' if side<0 else 'R')
 beam((0,.31,.4),(0,.56,.64),.055,m)
 if species=='dog':box('Collar',(0,-.29,.49),(.28,.05,.15),'clay')
 if species=='deer':
  for side in [-1,1]:
   beam((side*.08,-.35,.8),(side*.25,-.30,1.2),.026,'wood');beam((side*.19,-.30,1.09),(side*.32,-.15,1.16),.022,'wood')
 for o in bpy.context.scene.objects:
  if o.type=='MESH':o.location*=scale;o.scale*=scale
 export(species)
reset()
verts=[];faces=[]
for j in range(9):
 y=-.95+j*.2375;w=.37*(1-.80*(abs(y)/.95)**3)
 for x,z in [(-w,.12),(-w*.65,-.14),(w*.65,-.14),(w,.12)]:verts.append((x,y,z))
for j in range(8):
 for k in range(3):a=j*4+k;faces.append((a,a+4,a+5,a+1))
faces.extend([(0,1,2,3),(32,35,34,33)])
mesh=bpy.data.meshes.new('Carved hull');mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new('Wooden rescue boat',mesh);bpy.context.collection.objects.link(obj);mat(obj,'oak')
for y in [-.55,0,.55]:box('Bench',(0,y,.06),(.52,.12,.08),'plank')
beam((-.40,-.65,.15),(.45,.65,.15),.025,'cream')
export('boat')
