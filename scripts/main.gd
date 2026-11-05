extends Node3D
const Simulation=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/world_view.gd")
const Rules=preload("res://scripts/rules.gd")
const INK=Color("f0ecdd")
const MUTED=Color("a5b7b6")
const GOLD=Color("efcc88")
var sim=Simulation.new()
var world: WorldView
var camera: Camera3D
var sunlight: DirectionalLight3D
var ui: Control
var mobile_ui=OS.has_feature("android") or "--mobile-ui" in OS.get_cmdline_user_args()
var stats: Label
var clock_label: Label
var toast_label: Label
var hint: Label
var selected_button: Button
var tray: HBoxContainer
var tab_buttons={}
var pause_button: Button
var speed_button: Button
var modal: PanelContainer
var modal_shade: ColorRect
var modal_pause_before=false
var category="Powers"
var mode="inspect"
var selected=-1
var target=Vector2(-6,0)
var zoom=32.0
var target_zoom=32.0
var speed=1
var accumulator=0.0
var toast_timer=0.0
var hud_timer=0.0
var autosave_elapsed=0.0
var pointer_down=false
var dragging=false
var drag_start=Vector2.ZERO
var touch_points={}
var pinch_distance=0.0
var move_pad: GridContainer
var hold_direction=Vector2.ZERO
var high_quality=true
var reduced_motion=false
var high_contrast=false
var display_font: Font
var body_font: Font
var frame_samples: Array=[]
var audio_on=false
var audio_player: AudioStreamPlayer
var sound_volume=-20.0
var pending={}

func _ready() -> void:
 Engine.max_fps=60;get_tree().quit_on_go_back=false
 if mobile_ui:get_window().content_scale_size=Vector2i(1280,720)
 display_font=load("res://assets/fonts/Display.ttf");body_font=load("res://assets/fonts/Inter.ttf")
 sim.setup();setup_environment()
 world=View.new();add_child(world);world.setup(sim)
 camera=Camera3D.new();add_child(camera);camera.fov=44;camera.near=.12;camera.far=600
 setup_ui();update_camera();update_hud();populate_tray()
 audio_player=AudioStreamPlayer.new();add_child(audio_player);audio_player.volume_db=sound_volume
 toast("Welcome to your living planet. Drag to explore. Tap a person to take control.",8)
 for flag in ["--smoke","--input-smoke","--showcase"]:
  if flag in OS.get_cmdline_user_args():
   await get_tree().process_frame
   if flag=="--smoke":run_smoke()
   elif flag=="--input-smoke":run_input_smoke()
   else:run_showcase()
func setup_environment() -> void:
 var environment=Environment.new();environment.background_mode=Environment.BG_SKY
 var sky=Sky.new();var shader=Shader.new()
 shader.code="shader_type sky;void sky(){vec3 d=EYEDIR;float s=pow(max(0.0,sin(d.x*913.4)*sin(d.y*736.3)*sin(d.z*844.8)),80.0);COLOR=vec3(.008,.018,.032)+vec3(.012,.021,.032)*max(0.0,d.y)+vec3(s*.65);}"
 var material=ShaderMaterial.new();material.shader=shader;sky.sky_material=material;environment.sky=sky
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("adbfcb");environment.ambient_light_energy=.68;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 var node=WorldEnvironment.new();node.environment=environment;add_child(node)
 sunlight=DirectionalLight3D.new();sunlight.rotation_degrees=Vector3(-38,-28,0);sunlight.light_color=Color("fff0d6");sunlight.light_energy=1.20;sunlight.shadow_enabled=true;sunlight.shadow_bias=.035;sunlight.directional_shadow_max_distance=100;sunlight.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;add_child(sunlight)
func update_camera() -> void:
 var up=sim.normal_at(target.x,target.y);var east=Vector3(cos(target.x/Simulation.RADIUS),0,-sin(target.x/Simulation.RADIUS));var south=east.cross(up)
 var point=sim.surface(target.x,target.y,.3)
 var pullback=smoothstep(40,125,zoom)
 var center=point.lerp(south*13.0,pullback)
 var local_eye=point+up*zoom*.79+south*zoom*.58+east*zoom*.15
 var global_eye=up*(Simulation.PLANET_RADIUS+zoom*1.55)+south*zoom*.05
 camera.position=local_eye.lerp(global_eye,pullback)
 camera.look_at(center,up.lerp(-south,pullback).normalized())
 if world.earthquake_shake!=0:camera.position+=east*world.earthquake_shake
 world.globe_mode=zoom>65;world.focus=target
 world.vegetation.visible=zoom<95;world.citizens.visible=zoom<80;world.structures.visible=zoom<105
func screen_to_world(screen: Vector2) -> Variant:
 var origin=camera.project_ray_origin(screen);var direction=camera.project_ray_normal(screen)
 var query=PhysicsRayQueryParameters3D.create(origin,origin+direction*600,1)
 var result=get_world_3d().direct_space_state.intersect_ray(query)
 if not result.is_empty():
  var n: Vector3=result.position.normalized()
  return Vector2(atan2(n.x,n.z)*Simulation.RADIUS,asin(clampf(n.y,-1,1))*Simulation.RADIUS)
 var r=Simulation.PLANET_RADIUS+.10;var b=origin.dot(direction);var discriminant=b*b-origin.length_squared()+r*r
 if discriminant<0:return null
 var hit=origin+direction*(-b-sqrt(discriminant));var normal=hit.normalized()
 return Vector2(atan2(normal.x,normal.z)*Simulation.RADIUS,asin(clampf(normal.y,-1,1))*Simulation.RADIUS)
func style(color: Color,border: Color=Color("344b4b"),radius: int=12,padding: int=14) -> StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(radius);s.content_margin_left=padding;s.content_margin_right=padding;s.content_margin_top=padding;s.content_margin_bottom=padding;return s
func panel(parent: Node) -> PanelContainer:
 var p=PanelContainer.new();p.add_theme_stylebox_override("panel",style(Color("020c12") if high_contrast else Color(.035,.075,.09,.96),GOLD if high_contrast else Color("344b4b")));parent.add_child(p);return p
func label(text: String,size: int=18,color: Color=INK,parent: Node=null) -> Label:
 var l=Label.new();l.text=text;l.add_theme_color_override("font_color",color);l.add_theme_font_size_override("font_size",size)
 if parent!=null:parent.add_child(l)
 return l
func button(text: String,callback: Callable,parent: Node,width: float=0) -> Button:
 var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(width,72 if mobile_ui else 52);b.focus_mode=Control.FOCUS_NONE;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;b.add_theme_font_size_override("font_size",22 if mobile_ui else 17);b.add_theme_color_override("font_color",INK)
 b.add_theme_stylebox_override("normal",style(Color("173038"),Color("38585d"),9,10));b.add_theme_stylebox_override("hover",style(Color("28464b"),GOLD,9,10));b.add_theme_stylebox_override("pressed",style(Color("4a574c"),GOLD,9,10))
 b.pressed.connect(callback,CONNECT_DEFERRED);parent.add_child(b);return b
func paragraph(text: String,parent: Node,color: Color=MUTED) -> Label:
 var l=label(text,22 if mobile_ui else 17,color,parent);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x=minf(480,get_viewport().get_visible_rect().size.x-100);return l
func separator(parent: Node) -> void:
 var s=HSeparator.new();s.modulate=Color("4b6669");parent.add_child(s)
func setup_ui() -> void:
 var canvas=CanvasLayer.new();add_child(canvas);ui=Control.new();canvas.add_child(ui);ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var theme=Theme.new();theme.default_font=body_font;theme.default_font_size=22 if mobile_ui else 17;ui.theme=theme
 var header=panel(ui);header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);header.offset_left=16;header.offset_right=-16;header.offset_top=12;header.offset_bottom=104
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",16);header.add_child(row)
 var brand=VBoxContainer.new();row.add_child(brand);brand.custom_minimum_size.x=178
 var title=label("Worldkeeper",31,INK,brand);title.add_theme_font_override("font",display_font);label("THE LIVING PLANET",11,GOLD,brand)
 var resource_col=VBoxContainer.new();resource_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(resource_col)
 stats=label("",22 if mobile_ui else 20,INK,resource_col);clock_label=label("",16 if mobile_ui else 14,MUTED,resource_col)
 pause_button=button("Pause",toggle_pause,row,80);speed_button=button("1x",cycle_speed,row,58);button("Earth",toggle_globe,row,78);button("Menu",show_menu,row,78)
 var info=HBoxContainer.new();info.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(info);info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);info.offset_left=22;info.offset_right=-22;info.offset_top=118;info.offset_bottom=170
 selected_button=button("People & orders",func():
  if selected>=0:show_person(selected)
  else:show_people(),info,180)
 var spacer=Control.new();spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.add_child(spacer)
 button("Objectives",show_objectives,info,130)
 var bottom=panel(ui);bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_left=16;bottom.offset_right=-16;bottom.offset_top=-224 if mobile_ui else -182;bottom.offset_bottom=-12
 var col=VBoxContainer.new();bottom.add_child(col);col.add_theme_constant_override("separation",8)
 var tabs=HBoxContainer.new();tabs.add_theme_constant_override("separation",7);col.add_child(tabs)
 for name in ["Powers","Disasters","Build","People","Life","World"]:
  var n=name;var b=button(n,func():category=n;cancel_tool();populate_tray(),tabs,105 if mobile_ui else 116);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab_buttons[n]=b
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(scroll)
 tray=HBoxContainer.new();tray.add_theme_constant_override("separation",8);scroll.add_child(tray)
 var toast_panel=panel(ui);toast_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);toast_panel.offset_left=100;toast_panel.offset_right=-100;toast_panel.offset_top=-304 if mobile_ui else -242;toast_panel.offset_bottom=-236 if mobile_ui else -194;toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 toast_label=label("",16,INK,toast_panel);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hint=label("Drag to orbit your world  |  Pinch to zoom from person to planet",14,MUTED,ui);hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);hint.offset_left=-400;hint.offset_right=400;hint.offset_top=-330 if mobile_ui else -270;hint.offset_bottom=-308 if mobile_ui else -246;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 move_pad=GridContainer.new();ui.add_child(move_pad);move_pad.columns=3;move_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);move_pad.offset_left=20;move_pad.offset_top=-460;move_pad.offset_bottom=-260;move_pad.visible=false
 for dir in [Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1),Vector2(-1,0),Vector2.ZERO,Vector2(1,0),Vector2(-1,1),Vector2(0,1),Vector2(1,1)]:
  var d=dir;var b=button("UP" if d.y<0 else "DOWN" if d.y>0 else "LEFT" if d.x<0 else "RIGHT" if d.x>0 else "Stop",func():pass,move_pad,64)
  b.add_theme_font_size_override("font_size",12);b.button_down.connect(func():hold_direction=d.normalized());b.button_up.connect(func():hold_direction=Vector2.ZERO)
func populate_tray() -> void:
 for child in tray.get_children():child.queue_free()
 for name in tab_buttons:tab_buttons[name].modulate=GOLD if name==category else Color.WHITE
 match category:
  "Powers","Disasters":
   var list=["rain","heal","forest","shield","raise","lower","lightning","wind","cool","resurrect","spawn"] if category=="Powers" else ["fire","flood","tornado","quake","meteor","drought","lightning"]
   for kind in list:
    var k=kind;var r=Rules.POWERS[k];var b=button(r.title+"\n"+("Free" if sim.sandbox else "%d faith"%r.cost),func():choose_tool(k),tray,140);b.custom_minimum_size.y=76
  "Build":
   for kind in Rules.BUILDINGS:
    var k=kind;var rule=Rules.BUILDINGS[k];var b=button(rule.title+"\n%d timber"%rule.wood,func():choose_tool("build:"+k),tray,162);b.custom_minimum_size.y=76;b.disabled=rule.era>sim.era
  "People":
   button("Command\neveryone",show_settlement_orders,tray,150)
   for p in sim.people:
    var id=p.id;button(p.name+"\n"+(p.task.capitalize() if p.alive else "Died"),func():select_person(id);show_person(id),tray,130)
  "Life":
   button("Families &\npopulation",show_families,tray,168);button("Pets &\nwildlife",show_animals,tray,156)
   for species in ["dog","cat","deer"]:
    var s=species;button("Create "+s+"\nChoose a place",func():choose_tool("animal:"+s),tray,150)
   button("Create person",func():choose_tool("spawn"),tray,160);button("Resurrection",func():choose_tool("resurrect"),tray,160)
  "World":
   button("Civilization\n"+Rules.ERAS[sim.era],show_civilization,tray,174);button("Cedar Camp\nDiplomacy",show_diplomacy,tray,156);button("World laws",show_settlement_orders,tray,150);button("Chronicle",show_chronicle,tray,150);button("Climate",show_climate,tray,140);button("Sandbox",show_sandbox,tray,140)
func choose_tool(tool: String) -> void:
 mode=tool
 if zoom>45:target_zoom=28
 var title=Rules.BUILDINGS[tool.trim_prefix("build:")].title if tool.begins_with("build:") else "a "+tool.trim_prefix("animal:") if tool.begins_with("animal:") else Rules.POWERS.get(tool,{"title":tool}).title
 hint.text="Tap the world: "+title+"  |  Cancel with Back / Escape"
 toast("Choose where to use "+title+".",5)
func cancel_tool() -> void:
 mode="inspect";pending={};world.brush.visible=false;hint.text="Drag to orbit your world  |  Pinch to zoom from person to planet"
func toast(text: String,duration: float=5) -> void:
 if toast_label==null:return
 toast_label.text=text;toast_timer=duration
func update_hud() -> void:
 if stats==null:return
 stats.text="%d people  |  %d grain  |  %d timber"%[sim.alive_count(),int(sim.grain),int(sim.wood)]
 clock_label.text="%s  •  DAY %d  •  %s  •  %s"%[Rules.ERAS[sim.era],sim.tick/Simulation.DAY+1,"SANDBOX" if sim.sandbox else "%d FAITH"%sim.energy,"PAUSED" if sim.paused else "%.1fs"%(sim.tick*Simulation.DT)]
 pause_button.text="Play" if sim.paused else "Pause";speed_button.text=str(speed)+"x"
 var p=sim.person(selected)
 selected_button.text=p.name+" • "+p.task.capitalize() if not p.is_empty() else "People & orders"
 move_pad.visible=sim.possessed>=0 and not is_instance_valid(modal)
 if toast_timer<=0:toast_label.text=sim.weather+"  |  "+("All miracles are free. You control every life." if sim.sandbox else "Faith regenerates, even after extinction.")
func open_modal(title: String) -> VBoxContainer:
 if not is_instance_valid(modal):modal_pause_before=sim.paused
 else:
  modal_shade.queue_free();modal=null
 sim.paused=true;hold_direction=Vector2.ZERO
 modal_shade=ColorRect.new();modal_shade.color=Color(0,0.015,.025,.74);ui.add_child(modal_shade);modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal_shade.mouse_filter=Control.MOUSE_FILTER_STOP
 modal=panel(modal_shade);modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 var screen=get_viewport().get_visible_rect().size;var width=minf(620,screen.x-40);var height=minf(680,screen.y-44)
 modal.offset_left=-width/2;modal.offset_right=width/2;modal.offset_top=-height/2;modal.offset_bottom=height/2
 var wrapper=VBoxContainer.new();wrapper.add_theme_constant_override("separation",12);modal.add_child(wrapper)
 var header=HBoxContainer.new();wrapper.add_child(header);var heading=label(title,30,INK,header);heading.add_theme_font_override("font",display_font);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button("Close",close_modal,header,80)
 separator(wrapper)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;wrapper.add_child(scroll)
 var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",10);scroll.add_child(body)
 update_hud();return body
func close_modal() -> void:
 if is_instance_valid(modal_shade):modal_shade.queue_free()
 modal=null;modal_shade=null;sim.paused=modal_pause_before;pending={};hold_direction=Vector2.ZERO;update_hud()
func show_objectives() -> void:
 var col=open_modal("A living world")
 var goals=sim.objectives();var text=["Meet one of your people","Give a direct order","Complete a storehouse","Welcome a new generation","Construct the observatory"]
 for i in goals.size():paragraph(("DONE  " if goals[i] else "NEXT  ")+text[i],col,GOLD if goals[i] else INK)
 separator(col);paragraph("Day three brings a dangerous flood. Evacuate, build a levee, reshape the riverbank, or negotiate rescue boats. Fire, deep water, lightning and violent winds can kill unprotected people.",col)
 button("Evacuate the settlement",func():sim.evacuate();close_modal();toast("Evacuation ordered. People will stay where you ordered them."),col)
 button("How to play",show_help,col)
func show_help() -> void:
 var col=open_modal("Your world, your will")
 paragraph("EXPLORE\nDrag the planet to orbit. Pinch or use the mouse wheel to zoom smoothly from people to the entire Earth. Earth switches between a whole-planet view and your settlement.",col)
 paragraph("CONTROL PEOPLE\nTap a person, or choose People. Give an order, then tap the destination. Move ends with a persistent Hold order. They will not wander away until you choose Resume autonomy. Possession gives you the movement pad or WASD. Release returns control to the AI.",col)
 paragraph("BUILD\nChoose Build and place a foundation on clear dry land. Free builders travel there and construct it. If you gave a builder a direct order, release that order before expecting automatic work.",col)
 paragraph("ELEMENTS\nWater and rain put out fire. Wet ground resists ignition. Wind carries flames. Lightning follows connected water and electrocutes people. Fire and deep floodwater kill quickly. Shields protect people in their area. Earthquakes damage homes; tornadoes pull people and cause injuries.",col)
 paragraph("LIFE\nOpen Life for pets, reproduction policies and families. Pair adults, bless a birth, delay or cancel a pregnancy, or pause natural reproduction. Children follow their families; you can also guide their growth.",col)
func show_people() -> void:
 var col=open_modal("Your people")
 for p in sim.people:
  var id=p.id;button(p.name+"  •  "+("Health %d"%p.health if p.alive else "Died"),func():select_person(id);show_person(id),col)
func select_person(id: int) -> void:
 selected=id;world.selected=id;sim.inspected=true;cancel_tool();update_hud()
func show_person(id: int) -> void:
 var p=sim.person(id)
 if p.is_empty():return
 selected=id;world.selected=id;sim.inspected=true
 var col=open_modal(p.name)
 paragraph("%s  •  %d years  •  %s\nHealth %d%%  |  Hunger %d%%  |  Fatigue %d%%\nCurrent action: %s\n%s"%[p.job,int(p.age),p.authority,int(p.health),int(p.hunger),int(p.fatigue),p.task.capitalize(),p.blocked if not p.blocked.is_empty() else "Your explicit orders always take priority."],col)
 if not p.alive:
  button("Resurrect this person",func():sim.power("resurrect",p.x,p.z,true);world.sync();show_person(id),col);return
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);col.add_child(row)
 button("Follow camera",func():target=Vector2(p.x,p.z);target_zoom=16;close_modal(),row)
 button("Release" if sim.possessed==id else "Possess",func():
  if sim.possessed==id:sim.release();toast("Autonomy restored.")
  else:toast(sim.possess(id));target=Vector2(p.x,p.z);target_zoom=17
  close_modal(),row)
 button("Give or queue an order",func():show_orders(id),col)
 button("Hold position",func():toast(sim.order(id,"hold",p.x,p.z));close_modal();world.sync(),col)
 button("Resume autonomy",func():sim.resume(id);close_modal();toast(p.name+" is free to choose work."),col)
 button("Lift to a new location",func():close_modal();mode="lift";hint.text="Tap dry ground to place "+p.name+". They will stay there.";toast("Choose a safe place for "+p.name+"."),col)
 button("Role & family",func():show_person_life(id),col)
 button("Heal this person",func():sim.power("heal",p.x,p.z,true);world.sync();show_person(id),col)
 button("End this life…",func():
  var confirm=open_modal("End "+p.name+"'s life?");paragraph("This kills the selected person. Resurrection remains available in your world.",confirm)
  button("Confirm: end this life",func():sim.damage(p,1000,"a divine decree");world.sync();close_modal();toast(p.name+" has died."),confirm),col)
func show_orders(id: int) -> void:
 var col=open_modal("Give an order")
 paragraph("Choose an action, then tap a destination. The order remains yours until you release it. Build needs a foundation; Gather needs a forest.",col)
 for action in ["move","gather","build","rest","fight","rescue"]:
  var a=action;button(a.capitalize()+" • choose destination",func():selected=id;close_modal();mode="order:"+a;hint.text="Tap a destination: "+a;toast("Choose where "+sim.person(id).name+" should "+a+"."),col)
 button("Queue a move",func():selected=id;close_modal();mode="queue:move";hint.text="Tap a destination to queue after the current order.",col)
 button("Cancel all orders and hold",func():var p=sim.person(id);p.queue=[];sim.order(id,"hold",p.x,p.z);close_modal(),col)
func show_person_life(id: int) -> void:
 var p=sim.person(id);var col=open_modal(p.name+" • life")
 if p.age>=16:
  for job in ["Farmer","Builder","Hauler"]:
   var j=job;button("Work as "+j,func():p.job=j;sim.resume(id);show_person_life(id),col)
 if p.partner>=0:
  var partner=sim.person(p.partner);paragraph("Partner: "+partner.get("name","Unknown"),col)
  button("Bless a birth now",func():toast(sim.bless_birth(id));world.sync();show_person_life(id),col)
  button("Delay expected birth by one day",func():
   if p.pregnancy>0:p.pregnancy+=Simulation.DAY
   elif not partner.is_empty() and partner.pregnancy>0:partner.pregnancy+=Simulation.DAY
   toast("Expected birth delayed.");show_person_life(id),col)
  button("Cancel the expected birth",func():sim.cancel_birth(id);show_person_life(id),col)
 button("Choose a partner",func():show_partner_picker(id),col)
 if p.age<16:button("Guide this child to adulthood",func():p.age=18;p.job="Hauler";sim.resume(id);world.sync();show_person_life(id),col)
func show_partner_picker(id: int) -> void:
 var col=open_modal("Choose another adult")
 for p in sim.people:
  if p.id==id or not p.alive or p.age<18:continue
  var other=p.id;button(p.name,func():toast(sim.arrange_pair(id,other));show_person_life(id),col)
func show_families() -> void:
 var col=open_modal("Families & population")
 var children=0
 for p in sim.people:
  if p.alive and p.age<16:children+=1
 paragraph("%d people  •  %d children  •  %d births\nReproduction: %s. Natural growth needs healthy adults, food and spare beds. A pregnancy lasts two game days; your intervention can change it."%[sim.alive_count(),children,sim.births,sim.reproduction],col)
 for policy in ["Natural","Paused"]:
  var p=policy;button("Reproduction: "+p,func():sim.reproduction=p;show_families(),col)
 button("Choose a parent to intervene",show_people,col)
 for p in sim.people:
  if p.alive and p.pregnancy>0:
   var id=p.id;button(p.name+" • expecting in %.1f days"%(float(p.pregnancy-sim.tick)/Simulation.DAY),func():show_person_life(id),col)
func show_animals() -> void:
 var col=open_modal("Pets & wildlife")
 paragraph("Pets follow their owner, eat, roam and respond to dangers. Animals can die from fire, lightning and drowning. You can heal or resurrect them with your powers.",col)
 for a in sim.animals:
  var id=a.id;button(a.name+" • "+a.species+" • "+("%d%% health"%a.health if a.alive else "Died"),func():show_animal(id),col)
func show_animal(id: int) -> void:
 var a={}
 for animal in sim.animals:
  if animal.id==id:a=animal;break
 if a.is_empty():return
 var col=open_modal(a.name);paragraph("%s  •  %s\nHealth %d%%  |  Hunger %d%%"%[a.species,a.mode,a.health,a.hunger],col)
 button("Follow camera",func():target=Vector2(a.x,a.z);target_zoom=16;close_modal(),col)
 for policy in ["Follow","Stay","Roam"]:
  var p=policy
  button(p,func():
   a.mode=p
   if a.owner<0:a.owner=sim.people[0].id
   show_animal(id),col)
 button("Assign a new owner",func():
  var picker=open_modal("Choose an owner")
  for p in sim.people:
   if p.alive:
    var owner=p.id;button(p.name,func():a.owner=owner;a.mode="Follow";show_animal(id),picker),col)
 button("Heal / resurrect animal",func():a.health=100.0;a.hunger=0.0;a.alive=true;world.sync();show_animal(id),col)
func show_settlement_orders() -> void:
 var col=open_modal("Your civilization obeys")
 paragraph("These commands affect every living person. Explicit individual commands remain in force until you choose Resume autonomy.",col)
 button("Everyone: hold position",func():
  for p in sim.people:
   if p.alive:sim.order(p.id,"hold",p.x,p.z)
  close_modal();toast("Everyone holds position."),col)
 button("Everyone: resume autonomy",func():
  for p in sim.people:
   if p.alive:sim.resume(p.id)
  sim.evacuated=false;close_modal();toast("Your people can choose their work again."),col)
 button("Evacuate settlement",func():sim.evacuate();close_modal();toast("Evacuation ordered."),col)
 for policy in ["Balanced","Rationing"]:
  var p=policy;button("Food policy: "+p,func():sim.policy=p;show_settlement_orders(),col)
func show_civilization() -> void:
 var col=open_modal("Civilization • "+Rules.ERAS[sim.era])
 paragraph("Knowledge: %d\nNext requirement: %s"%[sim.knowledge,sim.era_requirement() if not sim.era_requirement().is_empty() else "All requirements met."],col)
 button("Research the next age",func():toast(sim.research());populate_tray();show_civilization(),col)
 button("Command the settlement",show_settlement_orders,col)
func show_diplomacy() -> void:
 var col=open_modal("Cedar Camp")
 paragraph("Trust: %d. %s\nTrade brings grain and rescue boats. A hostile camp can raid your stores; two guards can repel a raid."%[sim.relation,"Truce active." if sim.treaty else "No treaty."],col)
 for entry in [["trade","Trade 20 timber for grain & rescue boats"],["tribute","Offer 15 grain in tribute"],["treaty","Negotiate a truce"],["threaten","Threaten the camp"]]:
  var a=entry[0];button(entry[1],func():toast(sim.diplomacy(a));show_diplomacy(),col)
func show_chronicle() -> void:
 var col=open_modal("Your world's story")
 for e in sim.events.slice(0,30):
  var event=e;button("Day %d • %s"%[int(e.tick)/Simulation.DAY+1,e.title],func():target=Vector2(event.x,event.z);target_zoom=24;close_modal();toast(event.detail,10),col)
func show_climate() -> void:
 var col=open_modal("Ecosystem & elements")
 paragraph("Weather: %s\nTemperature: %.1f °C\nLong-term heat trend: %+.2f °C\n\nRain and water extinguish fire. Wet ground resists ignition. Lightning conducts through connected water. Wind spreads flames. Forests use carbon; industry adds heat. Animal welfare, food and shelter affect population."%[sim.weather,sim.temperature,sim.heat],col)
 for overlay in ["Natural","Danger","Climate"]:
  var o=overlay;button(o+" overlay",func():world.overlay=o;world.rebuild_terrain();close_modal(),col)
func show_sandbox() -> void:
 var col=open_modal("Divine authority")
 button("Mode: "+("Sandbox" if sim.sandbox else "Challenge"),func():sim.sandbox=not sim.sandbox;show_sandbox();populate_tray(),col)
 if sim.sandbox:
  button("Create 100 grain and 100 timber",func():sim.grain+=100;sim.wood+=100;show_sandbox();update_hud(),col)
  button("Resurrect everyone",func():
   sim.release()
   for p in sim.people:p.alive=true;p.health=100.0;p.hunger=0.0;sim.resume(p.id)
   world.sync();close_modal();toast("Every person is alive again."),col)
  button("Choose a faction: "+("Riverhaven" if sim.active_faction==0 else "Cedar Camp"),func():sim.active_faction=1-sim.active_faction;show_sandbox(),col)
func save_user_world() -> bool:
 var current=sim.paused
 if is_instance_valid(modal):sim.paused=modal_pause_before
 var saved=sim.save_world();sim.paused=current;return saved
func show_menu() -> void:
 var col=open_modal("Worldkeeper • Living Planet")
 button("Return to world",close_modal,col)
 button("Save world",func():toast("World saved." if save_user_world() else "Could not save; previous save retained.");close_modal(),col)
 button("Load world",func():
  if sim.load_world():modal_pause_before=sim.paused;rebuild_world();toast("World restored.")
  else:toast("No valid save found.")
  close_modal(),col)
 button("Graphics: "+("High" if high_quality else "Battery"),func():high_quality=not high_quality;sunlight.shadow_enabled=high_quality;world.high_quality=high_quality;get_viewport().msaa_3d=Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED;show_menu(),col)
 button("Reduced motion: "+("On" if reduced_motion else "Off"),func():reduced_motion=not reduced_motion;world.reduced_motion=reduced_motion;show_menu(),col)
 button("High contrast: "+("On" if high_contrast else "Off"),func():high_contrast=not high_contrast;apply_contrast(ui);show_menu(),col)
 button("Sound effects: "+("On" if audio_on else "Off"),func():audio_on=not audio_on;show_menu(),col)
 var slider=HSlider.new();slider.min_value=-40;slider.max_value=0;slider.value=sound_volume;slider.custom_minimum_size.y=38;slider.value_changed.connect(func(v):sound_volume=v;audio_player.volume_db=v);col.add_child(slider)
 button("How to play",show_help,col)
 button("New world / restart",show_new_world,col)
 button("Credits & limits",func():
  var page=open_modal("Original world, original models");paragraph("Worldkeeper 0.2.0 • Godot 4.6.3. Original GLB models, animation, planet, interface, effects and sound. Fonts: Inter and Cormorant Garamond, SIL OFL. Genre inspiration: The Universim. Element interactions are deterministic game physics, not a scientific fluid solver. Physical Android performance still depends on your device.",page),col)
func apply_contrast(node: Node) -> void:
 for child in node.get_children():
  if child is PanelContainer:child.add_theme_stylebox_override("panel",style(Color("020c12") if high_contrast else Color(.035,.075,.09,.96),GOLD if high_contrast else Color("344b4b")))
  apply_contrast(child)
func show_new_world() -> void:
 var col=open_modal("Begin a new world?");paragraph("This replaces the current world. Save first if you want to keep it.",col)
 var input=LineEdit.new();input.text=str(sim.seed_value);input.custom_minimum_size.y=56;col.add_child(input)
 button("Create world from seed",func():
  if not input.text.is_valid_int():toast("Enter a whole-number seed.");return
  var value=int(input.text);sim=Simulation.new();sim.setup(value);selected=-1;target=Vector2(-6,0);target_zoom=24;rebuild_world();modal_pause_before=false;close_modal();toast("A new living planet awaits."),col)
func rebuild_world() -> void:
 remove_child(world);world.queue_free();world=View.new();add_child(world);world.setup(sim);world.selected=selected;world.high_quality=high_quality;world.reduced_motion=reduced_motion;cancel_tool();update_camera();populate_tray();update_hud()
func toggle_pause() -> void:sim.paused=not sim.paused;accumulator=0.0;update_hud()
func cycle_speed() -> void:speed=4 if speed==1 else 8 if speed==4 else 16 if speed==8 else 1;update_hud()
func toggle_globe() -> void:target_zoom=160 if target_zoom<65 else 24;toast("Drag to explore any side of your planet. Zoom in anywhere." if target_zoom>65 else "Returning to the surface.")
func preview_power(kind: String,x: float,z: float) -> void:
 var rule=Rules.POWERS[kind];var affected=0
 for p in sim.people:
  if p.alive and sim.distance(Vector2(p.x,p.z),Vector2(x,z))<=rule.radius:affected+=1
 world.show_brush(x,z,rule.radius);pending={"kind":kind,"x":x,"z":z}
 var col=open_modal(rule.title)
 paragraph("%d living people within the footprint.\n%s\n\n%s"%[affected,"Free miracle" if sim.sandbox else "%d faith"%rule.cost,"DESTRUCTIVE: this can kill people and animals and damage their world. Shields can protect them." if rule.get("danger",false) else "Rain puts out flames. Water conducts lightning. Every action changes the same living planet."],col,GOLD if rule.get("danger",false) else INK)
 button("Confirm "+rule.title,func():
  toast(sim.power(kind,x,z,true));play_sound(kind);close_modal();world.sync();world.update_hazards();world.brush.visible=false;update_hud()
  if sim.paused:toast(rule.title+" cast. Press Play to let the world and damage advance."),col)
 button("Cancel miracle",func():close_modal();world.brush.visible=false,col)
func world_tap(screen: Vector2) -> void:
 if is_instance_valid(modal):return
 var pos=screen_to_world(screen)
 if pos==null:toast("Drag the Earth into view, then tap its surface.");return
 if mode.begins_with("build:"):
  toast(sim.place(mode.trim_prefix("build:"),pos.x,pos.y));world.sync();update_hud();return
 if mode.begins_with("animal:"):
  if not sim.is_safe(pos.x,pos.y):toast("Choose dry land for this animal.");return
  sim.add_animal(mode.trim_prefix("animal:"),pos.x,pos.y,selected);world.sync();toast("A new animal joins your world.");return
 if mode.begins_with("order:") or mode.begins_with("queue:"):
  toast(sim.order(selected,mode.split(":")[1],pos.x,pos.y,mode.begins_with("queue:")));cancel_tool();world.sync();update_hud();return
 if mode=="lift":toast(sim.lift(selected,pos.x,pos.y));cancel_tool();world.sync();return
 if Rules.POWERS.has(mode):preview_power(mode,pos.x,pos.y);return
 if zoom>65:target=pos;target_zoom=30;toast("Zooming to this region.");return
 var best=-1;var best_distance=44.0
 for p in sim.people:
  var point=sim.surface(p.x,p.z,.6)
  if sim.normal_at(p.x,p.z).dot((camera.position-point).normalized())<.1:continue
  var d=camera.unproject_position(point).distance_to(screen)
  if d<best_distance:best_distance=d;best=p.id
 if best>=0:select_person(best);show_person(best);return
 for a in sim.animals:
  if sim.distance(pos,Vector2(a.x,a.z))<1.1:show_animal(a.id);return
 for b in sim.buildings:
  if sim.distance(pos,Vector2(b.x,b.z))<1.5:
   var col=open_modal(Rules.BUILDINGS[b.kind].title);paragraph("Health: %d%%\nConstruction: %d%%\n%s"%[b.health,int(b.work/Rules.BUILDINGS[b.kind].work*100),"Operational" if b.complete else "Builders are travelling or working here."],col)
   if not b.complete:
    var id=b.id;button("Cancel and return timber",func():toast(sim.cancel_building(id));close_modal();world.sync(),col)
   return
 toast("Explore, choose a power, or tap a person to command them.")
func _input(event: InputEvent) -> void:
 # Release can end over a menu; clear camera drag state even if the GUI consumes it.
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:call_deferred("clear_drag")
 if event is InputEventScreenTouch and not event.pressed:call_deferred("clear_touch",event.index)
func clear_drag() -> void:pointer_down=false
func clear_touch(index: int) -> void:touch_points.erase(index)
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed:
  if event.keycode==KEY_ESCAPE:
   if is_instance_valid(modal):close_modal()
   else:cancel_tool()
  if is_instance_valid(modal):return
  if event.keycode==KEY_SPACE:toggle_pause()
  elif event.keycode==KEY_TAB:toggle_globe()
  elif event.keycode==KEY_E and sim.possessed>=0 and not sim.paused:sim.wood+=1;toast("Gathered one timber.")
 if is_instance_valid(modal):return
 if event is InputEventScreenTouch:
  if event.pressed:
   touch_points[event.index]=event.position
   if touch_points.size()==1:drag_start=event.position;dragging=false
   elif touch_points.size()==2:pinch_distance=touch_points.values()[0].distance_to(touch_points.values()[1]);dragging=true
  else:
   touch_points.erase(event.index)
   if touch_points.is_empty() and not dragging:world_tap(event.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag:
  touch_points[event.index]=event.position
  if touch_points.size()>=2:
   var dist=touch_points.values()[0].distance_to(touch_points.values()[1])
   if pinch_distance>0:target_zoom=clampf(target_zoom*pinch_distance/maxf(dist,1),7,190)
   pinch_distance=dist
  else:
   if event.position.distance_to(drag_start)>9:dragging=true
   if dragging:pan_camera(event.relative)
 elif event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:target_zoom=clampf(target_zoom*.88,7,190)
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:target_zoom=clampf(target_zoom*1.12,7,190)
  elif event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:pointer_down=true;dragging=false;drag_start=event.position
   else:
    if pointer_down and not dragging:world_tap(event.position)
    pointer_down=false
 elif event is InputEventMouseMotion:
  if pointer_down and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
   if event.position.distance_to(drag_start)>8:dragging=true
   if dragging:pan_camera(event.relative)
  elif Rules.POWERS.has(mode):
   var p=screen_to_world(event.position)
   if p!=null:world.show_brush(p.x,p.y,Rules.POWERS[mode].radius)
func pan_camera(relative: Vector2) -> void:
 target.x=wrapf(target.x-relative.x*zoom/650,-128,128);target.y=clampf(target.y+relative.y*zoom/650,-60,60)
func _process(delta: float) -> void:
 if world==null or camera==null:return
 frame_samples.append(delta*1000)
 if frame_samples.size()>600:frame_samples.pop_front()
 if not sim.paused:accumulator+=minf(delta,.3)*speed
 var steps=0;var stepped=false
 while accumulator>=Simulation.DT and steps<80:
  accumulator-=Simulation.DT;sim.step();steps+=1;stepped=true
 if sim.paused:accumulator=0.0
 if sim.possessed>=0 and not sim.paused:
  var movement=hold_direction
  if Input.is_physical_key_pressed(KEY_W):movement.y-=1
  if Input.is_physical_key_pressed(KEY_S):movement.y+=1
  if Input.is_physical_key_pressed(KEY_A):movement.x-=1
  if Input.is_physical_key_pressed(KEY_D):movement.x+=1
  if movement.length()>0:
   movement=movement.normalized()*delta*2.4;sim.manual_move(movement.x,-movement.y);stepped=true
 if stepped:world.sync()
 world.animate(delta)
 zoom=target_zoom if reduced_motion else lerpf(zoom,target_zoom,1-exp(-delta*8));update_camera()
 hud_timer+=delta;toast_timer-=delta;autosave_elapsed+=delta
 if hud_timer>.25:update_hud();hud_timer=0.0
 if autosave_elapsed>60:save_user_world();autosave_elapsed=0.0
 move_pad.visible=sim.possessed>=0 and not is_instance_valid(modal)
func play_sound(kind: String) -> void:
 if not audio_on:return
 var rate=22050;var data=PackedByteArray();var duration=.6
 for i in int(rate*duration):
  var t=float(i)/rate;var amplitude=sin(t*TAU*(150 if kind in ["lightning","quake","meteor"] else 440))*exp(-t*7)*.3
  var sample=int(amplitude*32767);data.append(sample&255);data.append((sample>>8)&255)
 var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data;audio_player.stream=stream;audio_player.play()
func _notification(what: int) -> void:
 if sim==null or sim.cells.is_empty():return
 if what==MainLoop.NOTIFICATION_APPLICATION_PAUSED:save_user_world()
 elif what==Node.NOTIFICATION_WM_GO_BACK_REQUEST and ui!=null:
  if is_instance_valid(modal):close_modal()
  elif mode!="inspect":cancel_tool()
  else:show_menu()

# Integration hooks drive actual controls and events; no gameplay shortcuts are exposed.
func find_button(root: Node,text: String) -> Button:
 for child in root.get_children():
  if child.is_queued_for_deletion():continue
  if child is Button and child.text.begins_with(text) and child.is_visible_in_tree():return child
  var found=find_button(child,text)
  if found!=null:return found
 return null
func input_click(point: Vector2) -> void:
 point=get_viewport().get_final_transform()*point
 var motion=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion);await get_tree().process_frame
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=true;Input.parse_input_event(event);await get_tree().process_frame
 event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=false;Input.parse_input_event(event);await get_tree().process_frame
func input_button(text: String) -> void:
 var b=find_button(ui,text);assert(b!=null,"Missing button "+text)
 var parent=b.get_parent()
 while parent!=null:
  if parent is ScrollContainer:
   var diff=b.get_global_rect().end.y-parent.get_global_rect().end.y
   if diff>0:parent.scroll_vertical+=int(diff+5)
  parent=parent.get_parent()
 await get_tree().process_frame
 await input_click(b.get_global_rect().get_center());await get_tree().process_frame
func run_input_smoke() -> void:
 await get_tree().process_frame
 await input_button("People");await input_button("Amara");assert(selected==sim.people[0].id)
 await input_button("Give or queue");await input_button("Move •")
 await input_click(camera.unproject_position(sim.surface(-9,2,.1)));assert(sim.ordered)
 await input_button("Amara");await input_button("Possess");assert(sim.possessed==selected)
 await input_button("Amara");await input_button("Release");assert(sim.possessed==-1)
 await input_button("Build");await input_button("Storehouse");await input_click(camera.unproject_position(sim.surface(-1,-1,.1)));assert(sim.buildings.back().kind=="storehouse")
 await input_button("Powers");await input_button("Rain");await input_click(camera.unproject_position(sim.surface(target.x,target.y,.1)));await input_button("Confirm Rain");assert(sim.weather=="Rainfall")
 await input_button("Menu");assert(sim.paused);await input_button("Save world");assert(FileAccess.file_exists("user://worldkeeper-planet.json"))
 var saved=Simulation.new();assert(saved.load_world());assert(saved.paused==sim.paused)
 await input_button("Life");await input_button("Families");await input_button("Reproduction: Paused");assert(sim.reproduction=="Paused");await input_button("Close")
 await input_button("Menu");await input_button("High contrast")
 assert(high_contrast and modal.get_theme_stylebox("panel").bg_color==Color("020c12"))
 await input_button("Close")
 var screen=get_viewport().get_visible_rect().size;var center=Vector2(screen.x*.5,screen.y*.4);var before_zoom=target_zoom
 await input_touch(0,center-Vector2(60,0),true);await input_touch(1,center+Vector2(60,0),true)
 var drag=InputEventScreenDrag.new();drag.index=1;drag.position=get_viewport().get_final_transform()*(center+Vector2(120,0));drag.relative=Vector2(60,0);Input.parse_input_event(drag);await get_tree().process_frame
 await input_touch(1,center+Vector2(120,0),false);await input_touch(0,center-Vector2(60,0),false)
 assert(target_zoom<before_zoom)
 var old_target=target
 await input_touch(0,center,true)
 drag=InputEventScreenDrag.new();drag.index=0;drag.position=get_viewport().get_final_transform()*(center+Vector2(50,0));drag.relative=Vector2(50,0);Input.parse_input_event(drag);await get_tree().process_frame
 await input_touch(0,center+Vector2(50,0),false)
 assert(target!=old_target)
 var event=InputEventKey.new();event.keycode=KEY_SPACE;event.pressed=true;Input.parse_input_event(event);await get_tree().process_frame
 assert(sim.paused);var previous_tick=sim.tick;await get_tree().create_timer(.2).timeout;assert(sim.tick==previous_tick)
 print("INPUT_SMOKE_PASS: spherical picking, menus, orders, possession, build, rain, save, family policy, contrast, touch pinch/pan, pause")
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://builds/living-planet-ui.png")
 get_tree().quit()
func run_smoke() -> void:
 var id=sim.people[0].id;select_person(id);assert(sim.order(id,"move",-9,2).contains("ordered"));assert(sim.place("storehouse",-1,-1).contains("started"));sim.possess(id);sim.manual_move(.1,0);sim.release()
 assert(sim.save_world("user://smoke-v2.json"));assert(sim.load_world("user://smoke-v2.json"));world.sync();show_menu();close_modal();show_families();close_modal()
 await get_tree().create_timer(1).timeout
 print("UI_SMOKE_PASS: globe, models, people, commands, saves, menus, animals, families")
 get_tree().quit()
func run_showcase() -> void:
 sim.reproduction="Paused";sim.place("storehouse",-1,-1)
 for i in 400:sim.step()
 sim.paused=true;select_person(sim.people[0].id);world.sync()
 await get_tree().create_timer(2).timeout
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://builds/living-planet-surface.png")
 target_zoom=160
 await get_tree().create_timer(2).timeout
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://builds/living-planet-earth.png")
 target_zoom=22;target=Vector2(-6,0);sim.power("fire",-6,0,true);world.sync();world.update_hazards()
 await get_tree().create_timer(2).timeout
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://builds/living-planet-fire.png")
 for kind in ["rain","flood","lightning","quake","tornado"]:
  if kind=="rain":sim.power("rain",-6,0,true)
  else:sim.power(kind,-4,0,true)
  world.sync();world.update_hazards()
  await get_tree().create_timer(1.5).timeout
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://builds/living-planet-"+kind+".png")
 print("SHOWCASE_PASS");get_tree().quit()

func input_touch(index: int,point: Vector2,pressed: bool) -> void:
 var touch=InputEventScreenTouch.new();touch.index=index;touch.position=get_viewport().get_final_transform()*point;touch.pressed=pressed;Input.parse_input_event(touch);await get_tree().process_frame
