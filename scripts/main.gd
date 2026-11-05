extends Node3D
const Simulation = preload("res://scripts/simulation.gd")
const View = preload("res://scripts/world_view.gd")
const Rules = preload("res://scripts/rules.gd")
const INK = Color("eae7d4")
const MUTED = Color("a2b5a9")
const GOLD = Color("e2c68a")
var sim = Simulation.new()
var mobile_ui = OS.has_feature("android") or "--mobile-ui" in OS.get_cmdline_user_args()
var world: WorldView
var camera: Camera3D
var sunlight: DirectionalLight3D
var ui: Control
var stats: Label
var clock_label: Label
var weather_label: Label
var objective_labels: Array=[]
var inspector: VBoxContainer
var tray: HBoxContainer
var toast_label: Label
var toast_timer = 0.0
var speed = 1
var accumulator = 0.0
var selected = -1
var mode = "inspect"
var category = "Miracles"
var brush_point = Vector2.ZERO
var target = Vector3(-3,0,0)
var zoom = 33.0
var azimuth = 0.52
var pitch = 0.84
var drag_start = Vector2.ZERO
var dragging = false
var pointer_down = false
var touch_points = {}
var pinch_distance = 0.0
var pending = {}
var modal: PanelContainer
var pause_button: Button
var speed_button: Button
var inspector_panel: PanelContainer
var objectives_panel: PanelContainer
var selection_title: Label
var autosave_elapsed = 0.0
var high_quality = true
var reduced_motion = false
var high_contrast = false
var font_body: Font
var font_display: Font
var preview_label: Label
var hold_direction = Vector2.ZERO
var move_pad: GridContainer
var audio_on = false
var audio_player: AudioStreamPlayer
var audio_phase = 0.0
var audio_volume = -24.0
var total_frames = 0
var total_frame_time = 0.0

func _ready() -> void:
 get_tree().quit_on_go_back=false
 Engine.max_fps=60
 font_body=load("res://assets/fonts/Inter.ttf")
 font_display=load("res://assets/fonts/Display.ttf")
 sim.setup()
 setup_environment()
 world=View.new(); add_child(world); world.setup(sim)
 setup_camera()
 setup_ui()
 setup_audio()
 update_hud(); update_inspector(); populate_tray()
 toast("Welcome, Worldkeeper. Tap a settler to see the life in your hands.",8)
 if "--input-smoke" in OS.get_cmdline_user_args():
  await get_tree().process_frame
  run_input_smoke()
 if "--smoke" in OS.get_cmdline_user_args():
  await get_tree().process_frame
  run_smoke()
func setup_environment() -> void:
 var env=Environment.new()
 env.background_mode=Environment.BG_SKY
 var sky=Sky.new(); var sky_mat=ProceduralSkyMaterial.new()
 sky_mat.sky_top_color=Color("638b96"); sky_mat.sky_horizon_color=Color("d6d7b5"); sky_mat.ground_horizon_color=Color("c2cdb4"); sky_mat.ground_bottom_color=Color("405d56")
 sky.sky_material=sky_mat; env.sky=sky
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("b5d0c6"); env.ambient_light_energy=0.35
 env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 env.fog_enabled=true; env.fog_light_color=Color("b6c7b0"); env.fog_density=0.004; env.fog_sky_affect=0.2
 var environment=WorldEnvironment.new(); environment.environment=env; add_child(environment)
 sunlight=DirectionalLight3D.new(); sunlight.rotation_degrees=Vector3(-42,-38,0); sunlight.light_color=Color("fff0cb"); sunlight.light_energy=1.0; sunlight.shadow_enabled=true
 sunlight.directional_shadow_max_distance=95; sunlight.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; add_child(sunlight)
func setup_camera() -> void:
 camera=Camera3D.new(); add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=zoom; camera.far=350
 update_camera()
func update_camera() -> void:
 var center=Vector3(0,3,0) if world.globe_mode else target
 camera.position=center+Vector3(sin(azimuth)*cos(pitch),sin(pitch),cos(azimuth)*cos(pitch))*65
 camera.look_at(center); camera.size=zoom
func style(color: Color,border: Color=Color("4a5b4c"),radius: int=14) -> StyleBoxFlat:
 var s=StyleBoxFlat.new(); s.bg_color=color; s.border_color=border; s.set_border_width_all(1); s.set_corner_radius_all(radius)
 s.content_margin_left=16; s.content_margin_right=16; s.content_margin_top=12; s.content_margin_bottom=12
 return s
func panel(parent: Node,background: Color=Color(0.055,0.12,0.115,0.94)) -> PanelContainer:
 var p=PanelContainer.new(); p.add_theme_stylebox_override("panel",style(background)); parent.add_child(p); return p
func label(text: String,size: int=16,color: Color=INK,parent: Node=null) -> Label:
 var l=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",color)
 if parent!=null: parent.add_child(l)
 return l
func button(text: String,callback: Callable,parent: Node,width: float=0) -> Button:
 var b=Button.new(); b.text=text; b.custom_minimum_size=Vector2(width,64 if mobile_ui else 48); b.focus_mode=Control.FOCUS_NONE; b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 b.add_theme_stylebox_override("normal",style(Color("203b34"),Color("46604e"),9))
 b.add_theme_stylebox_override("hover",style(Color("365346"),GOLD,9))
 b.add_theme_stylebox_override("pressed",style(Color("5b6247"),GOLD,9))
 b.add_theme_font_size_override("font_size",15); b.add_theme_color_override("font_color",INK)
 b.pressed.connect(callback); parent.add_child(b); return b
func separator(parent: Node) -> void:
 var sep=HSeparator.new(); sep.modulate=Color("526452"); parent.add_child(sep)
func setup_ui() -> void:
 var layer=CanvasLayer.new(); add_child(layer)
 ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(ui)
 var theme=Theme.new(); theme.default_font=font_body; theme.default_font_size=16; ui.theme=theme
 var header=panel(ui); header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); header.offset_left=24; header.offset_right=-24; header.offset_top=20; header.offset_bottom=112
 var row=HBoxContainer.new(); row.add_theme_constant_override("separation",24); header.add_child(row)
 var brand=VBoxContainer.new(); brand.custom_minimum_size.x=235; row.add_child(brand)
 var title=label("Worldkeeper",36,INK,brand); title.add_theme_font_override("font",font_display)
 label("A CIVILIZATION IN YOUR HANDS",10,GOLD,brand)
 var resources=VBoxContainer.new(); resources.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(resources)
 stats=label("",19,INK,resources)
 clock_label=label("",12,MUTED,resources)
 var controls=HBoxContainer.new(); controls.add_theme_constant_override("separation",8); row.add_child(controls)
 pause_button=button("Ⅱ",toggle_pause,controls,50)
 speed_button=button("1×",cycle_speed,controls,54)
 button("◎ Planet",toggle_globe,controls,95)
 button("☰",show_menu,controls,50)
 objectives_panel=panel(ui); objectives_panel.position=Vector2(24,134); objectives_panel.custom_minimum_size=Vector2(245,0)
 var goals=VBoxContainer.new(); goals.add_theme_constant_override("separation",10); objectives_panel.add_child(goals)
 label("THE RIVER TEST",11,GOLD,goals)
 var goal_title=label("A fragile beginning",27,INK,goals); goal_title.add_theme_font_override("font",font_display)
 label("Guide twelve lives through the flood.",12,MUTED,goals)
 separator(goals)
 for text in ["Know one of your people","Give your first direct order","Complete a storehouse","Keep 8 alive through the storm","Restore the food supply"]:
  var l=label("○  "+text,12,MUTED,goals); objective_labels.append(l)
 separator(goals)
 weather_label=label("",12,INK,goals); weather_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; weather_label.custom_minimum_size.x=208
 button("Evacuate to high ground",func(): sim.evacuate(); toast("Evacuation ordered. Watch routes or lift anyone left behind."),goals)
 button("Speak with Cedar Camp",show_diplomacy,goals)
 inspector_panel=panel(ui); inspector_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); inspector_panel.offset_left=-282; inspector_panel.offset_right=-24; inspector_panel.offset_top=134; inspector_panel.offset_bottom=520
 inspector=VBoxContainer.new(); inspector.add_theme_constant_override("separation",8); inspector_panel.add_child(inspector)
 var bottom=panel(ui); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bottom.offset_left=24; bottom.offset_right=-24; bottom.offset_top=-202 if mobile_ui else -166; bottom.offset_bottom=-24
 var bottom_col=VBoxContainer.new(); bottom_col.add_theme_constant_override("separation",8); bottom.add_child(bottom_col)
 var tabs=HBoxContainer.new(); tabs.add_theme_constant_override("separation",8); bottom_col.add_child(tabs)
 for tab in ["Miracles","Settlement","People","Civilization","Chronicle"]:
  var t=tab; button(t,func(): category=t; mode="inspect"; world.brush.visible=false; populate_tray(),tabs)
 var spacer=Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tabs.add_child(spacer)
 button("Guide",show_objectives,tabs)
 button("−",func(): zoom=clampf(zoom+4,10,72); update_camera(),tabs,48)
 button("+",func(): zoom=clampf(zoom-4,10,72); update_camera(),tabs,48)
 button("⌂",func(): target=Vector3(-3,0,0); zoom=33; world.set_globe(false); update_camera(),tabs,48)
 var scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; bottom_col.add_child(scroll)
 tray=HBoxContainer.new(); tray.add_theme_constant_override("separation",8); scroll.add_child(tray)
 var toast_panel=panel(ui,Color(0.055,0.12,0.115,0.92)); toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); toast_panel.offset_left=-360; toast_panel.offset_right=360; toast_panel.offset_top=-270 if mobile_ui else -224; toast_panel.offset_bottom=-220 if mobile_ui else -180
 toast_label=label("",13,INK,toast_panel); toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 preview_label=label("Drag to explore  ·  Pinch to zoom  ·  Tap a person to inspect",12,Color("e7e5c9"),ui)
 preview_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); preview_label.offset_left=-350; preview_label.offset_right=350; preview_label.offset_top=-306 if mobile_ui else -251; preview_label.offset_bottom=-278 if mobile_ui else -228; preview_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 move_pad=GridContainer.new(); move_pad.columns=3; ui.add_child(move_pad); move_pad.position=Vector2(30,540); move_pad.visible=false
 for direction in [Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1),Vector2(-1,0),Vector2.ZERO,Vector2(1,0),Vector2(-1,1),Vector2(0,1),Vector2(1,1)]:
  var d=direction
  var b=button("•" if d==Vector2.ZERO else "↑" if d.y<0 else "↓" if d.y>0 else "←" if d.x<0 else "→",func(): pass,move_pad,48)
  b.button_down.connect(func(): hold_direction=d.normalized()); b.button_up.connect(func(): hold_direction=Vector2.ZERO)
 get_viewport().size_changed.connect(adapt_layout); adapt_layout()
func adapt_layout() -> void:
 if ui==null: return
 var width=get_viewport().get_visible_rect().size.x
 objectives_panel.visible=width>=1080 and not mobile_ui
 inspector_panel.visible=width>=880 and not mobile_ui
func populate_tray() -> void:
 for child in tray.get_children(): child.queue_free()
 match category:
  "Miracles":
   for kind in ["rain","heal","forest","raise","lower","shield","fire","lightning","resurrect","spawn","quake","wind","cool"]:
    var k=kind; var rule=Rules.POWERS[k]
    button(rule.title+"\n"+("∞ faith" if sim.sandbox else str(rule.cost)+" faith"),func(): choose_tool(k),tray,116)
  "Settlement":
   for kind in Rules.BUILDINGS:
    var k=kind; var rule=Rules.BUILDINGS[k]
    var b=button(rule.title+"\n"+str(rule.wood)+" timber",func(): choose_tool("build:"+k),tray,140)
    b.disabled=rule.era>sim.era
  "People":
   for p in sim.people:
    var id=p.id
    button(p.name+"\n"+(p.job if p.alive else "Departed"),func(): select_person(id); var person=sim.person(id); target=Vector3(person.x,0,person.z); update_camera(),tray,105)
  "Civilization":
   button("Research next age\n"+Rules.ERAS[sim.era],func(): toast(sim.research()); populate_tray(),tray,190)
   button("Camp diplomacy",show_diplomacy,tray,145)
   button("Laws & priorities",show_policies,tray,145)
   button("World overlays",show_overlays,tray,145)
   button("Climate record",show_climate,tray,145)
   button("Sandbox authority",show_sandbox,tray,165)
  "Chronicle":
   for event in sim.events.slice(0,15):
    var e=event
    button("Day %d · %s"%[int(e.tick)/Simulation.DAY+1,e.title],func(): target=Vector3(e.x,0,e.z); world.set_globe(false); update_camera(); toast(e.detail,10),tray,210)
func choose_tool(tool: String) -> void:
 if world.globe_mode: toggle_globe()
 mode=tool
 var text="Tap the world to place "+Rules.BUILDINGS[tool.trim_prefix("build:")].title if tool.begins_with("build:") else "Tap the world to preview "+Rules.POWERS.get(tool,{"title":tool}).title
 toast(text,6); preview_label.text=text+"  ·  Esc to cancel"
func update_hud() -> void:
 stats.text="%d people    •    %d grain    •    %d timber    •    %s faith"%[sim.alive_count(),int(sim.grain),int(sim.wood),"∞" if sim.sandbox else str(int(sim.energy))]
 var hour=6.0+fmod(float(sim.tick)/Simulation.DAY*24,24)
 clock_label.text="%s AGE   /   DAY %02d   /   %02d:%02d   /   %s"%[Rules.ERAS[sim.era],sim.tick/Simulation.DAY+1,int(hour)%24,int(fmod(hour,1)*60),"PAUSED" if sim.paused else "THE RIVER TEST"]
 var captions=["Know one of your people","Give your first direct order","Complete a storehouse","Keep 8 alive through the storm","Restore the food supply"]
 var goals=sim.objectives()
 for i in objective_labels.size():
  objective_labels[i].text=("✓  " if goals[i] else "○  ")+captions[i]
  objective_labels[i].modulate=GOLD if goals[i] else INK
 weather_label.text="FORECAST\n"+sim.weather+"\n"+("Heavy rain upstream on day 3.\nLow ground is at risk." if sim.tick<Simulation.DAY*2 else "River level: %.2f m\nLiving settlers: %d / 12"%[sim.flood,sim.alive_count()])
 pause_button.text="▶" if sim.paused else "Ⅱ"
 move_pad.visible=sim.possessed>=0
 if toast_timer<=0: toast_label.text="SANDBOX · Unrestricted miracles. Your choices shape every life." if sim.sandbox else "CHALLENGE · Miracles cost faith. It regenerates slowly."
 var solar=float(sim.tick)/Simulation.DAY*TAU
 sunlight.light_energy=0.6+0.4*cos(solar)
 sunlight.rotation_degrees.x=-42+sin(solar)*25
func update_inspector() -> void:
 for child in inspector.get_children(): child.queue_free()
 var p=sim.person(selected)
 label("THE INDIVIDUAL",11,GOLD,inspector)
 if p.is_empty():
  var title=label("Every life matters",28,INK,inspector); title.add_theme_font_override("font",font_display)
  var desc=label("Tap any settler in the world or open People. Inspect their needs, change their work, queue an order, or walk in their shoes.",14,MUTED,inspector); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.custom_minimum_size.x=210
  separator(inspector)
  label("YOU ARE THE GOD OF THIS WORLD",10,GOLD,inspector)
  button("Meet Amara",func(): select_person(sim.people[0].id),inspector)
  button("How to play",show_help,inspector)
  return
 var title=label(p.name,32,INK,inspector); title.add_theme_font_override("font",font_display)
 label("%s  ·  %d years  ·  %s"%[p.job,int(p.age),"Riverhaven" if p.faction==0 else "Cedar Camp"],12,MUTED,inspector)
 separator(inspector)
 for item in [["Health",p.health],["Nourishment",100-p.hunger],["Rest",100-p.fatigue]]:
  label("%s    %d%%"%[item[0],int(item[1])],12,INK,inspector)
  var bar=ProgressBar.new(); bar.custom_minimum_size.y=5; bar.show_percentage=false; bar.value=item[1]; bar.add_theme_stylebox_override("background",style(Color("294136"),Color.TRANSPARENT,3)); bar.add_theme_stylebox_override("fill",style(Color("bfba7c"),Color.TRANSPARENT,3)); inspector.add_child(bar)
 label("Intent: "+p.task.capitalize()+"   ·   Cargo: %d grain"%p.cargo,12,GOLD,inspector)
 var reason=label(p.blocked if not p.blocked.is_empty() else "Orders queued: %d. %s"%[p.queue.size(),"Awaiting your will." if p.task=="possessed" else "Your commands take priority over autonomy."],12,MUTED,inspector); reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; reason.custom_minimum_size.x=210
 var row=HBoxContainer.new(); row.add_theme_constant_override("separation",6); inspector.add_child(row)
 button("Release" if sim.possessed==p.id else "Possess",func():
  if sim.possessed==selected: sim.release(); toast("Autonomy restored.")
  else: toast(sim.possess(selected))
  update_inspector(),row)
 button("Command",show_orders,row)
 button("Lift to a new location",func(): mode="lift"; toast("Tap dry ground to place "+p.name+" safely."),inspector)
func select_person(id: int) -> void:
 selected=id; world.selected=id; sim.inspected=true; mode="inspect"; world.brush.visible=false; update_inspector(); update_hud()
 if not inspector_panel.visible: show_person_sheet()
func show_person_sheet() -> void:
 var p=sim.person(selected)
 if p.is_empty(): return
 var col=open_modal(p.name)
 paragraph("%s · Health %d%% · Hunger %d%% · Fatigue %d%%\nIntent: %s\n%s"%[p.job,p.health,p.hunger,p.fatigue,p.task,p.blocked],col)
 button("Release" if sim.possessed==selected else "Possess",func():
  if sim.possessed==selected: sim.release()
  else: toast(sim.possess(selected))
  close_modal(); update_inspector(),col)
 button("Give or queue an order",show_orders,col)
 button("Lift to a new location",func(): close_modal(); mode="lift"; toast("Tap dry ground to place "+p.name+"."),col)
 button("Return to world",close_modal,col)
func show_objectives() -> void:
 var col=open_modal("The River Test")
 var goals=sim.objectives()
 var captions=["Inspect one person","Give a direct order","Build a storehouse","Keep eight alive through the flood","Restore a working food route"]
 for i in goals.size(): label(("✓  " if goals[i] else "○  ")+captions[i],16,GOLD if goals[i] else INK,col)
 paragraph(sim.weather+". Heavy upstream rain arrives on day three. The western refuge is safe.",col)
 button("Evacuate to high ground",func(): sim.evacuate(); close_modal(); toast("Your people will hold at the refuge until the river recedes."),col)
 button("Speak with Cedar Camp",show_diplomacy,col)
 button("How to play",show_help,col)
func toast(text: String,seconds: float=4.0) -> void:
 toast_label.text=text; toast_timer=seconds
func open_modal(title: String) -> VBoxContainer:
 close_modal()
 modal=panel(ui,Color("142c28")); modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER); modal.offset_left=-290; modal.offset_right=290; modal.offset_top=-260; modal.offset_bottom=260
 var scroll=ScrollContainer.new(); modal.add_child(scroll); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",10); scroll.add_child(column)
 var row=HBoxContainer.new(); column.add_child(row)
 var heading=label(title,32,INK,row); heading.add_theme_font_override("font",font_display); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button("×",close_modal,row,48); separator(column)
 return column
func paragraph(text: String,parent: Node) -> void:
 var l=label(text,14,MUTED,parent); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x=480
func close_modal() -> void:
 if is_instance_valid(modal): modal.queue_free()
 modal=null; pending={}
func show_help() -> void:
 var col=open_modal("Your world, your will")
 paragraph("DRAG to explore. PINCH or + / − to zoom. Tap a person to inspect. Desktop: wheel zoom, right-drag orbit, Space pause, Tab planet view, Escape cancel.",col)
 paragraph("1. Meet Amara. Give a Move order, then tap dry land.\n2. Settlement → Storehouse → tap a free site near the village. Builders bring it to life.\n3. Before day three, evacuate to the west, trade for grain, or raise the low riverbank.\n4. Keep eight people alive and restore food after the flood.\n5. Research the ages and construct the observatory.",col)
 paragraph("POSSESSION: use the movement pad or WASD. E gathers timber. Release returns the person to their own decisions. Pausing freezes time and possession, while orders remain available.",col)
 paragraph("Miracles preview their affected area. Destructive miracles need a second tap on Confirm. Sandbox grants free powers, resurrection, life creation, faction authority, and stock editing.",col)
 button("Begin stewardship",close_modal,col)
func show_orders() -> void:
 if sim.person(selected).is_empty(): toast("Select a person first."); return
 var col=open_modal("Command "+sim.person(selected).name)
 for action in ["move","gather","build","rest","fight","rescue"]:
  var a=action
  button(a.capitalize()+" · choose destination",func(): close_modal(); mode="order:"+a; toast("Tap a destination for "+a+"."),col)
 button("Queue a move after current task",func(): close_modal(); mode="queue:move"; toast("Tap a destination to queue."),col)
 button("Cancel orders & release cargo",func(): var p=sim.person(selected); p.queue=[]; toast(sim.order(selected,"idle",p.x,p.z)); close_modal(); update_inspector(),col)
 for job in ["Farmer","Builder","Hauler"]:
  var j=job; button("Assign role: "+j,func(): sim.person(selected).job=j; close_modal(); update_inspector(),col)
func show_diplomacy() -> void:
 var col=open_modal("Cedar Camp")
 paragraph("Your neighbors need timber. Their grain stores are healthy, and they can send flood-rescue boats. Trust: %d. %s"%[sim.relation,"A truce is in force." if sim.treaty else "No treaty is in force."],col)
 for entry in [["trade","Trade 20 timber for grain & rescue boats"],["tribute","Offer 15 grain in tribute"],["treaty","Negotiate a lasting truce"],["threaten","Threaten the camp (−35 trust)"]]:
  var action=entry[0]; button(entry[1],func(): toast(sim.diplomacy(action)); show_diplomacy(); update_hud(),col)
 paragraph("A hostile camp can raid your stores. Trade and tribute improve trust. Treaties remain in effect when you save and reload.",col)
func show_policies() -> void:
 var col=open_modal("Laws & priorities")
 paragraph("Current policy: "+sim.policy+". Every direct order takes priority over this policy.",col)
 for policy in ["Balanced","Rationing"]:
  var p=policy; button(p+" · "+("reduce food consumption" if p=="Rationing" else "normal work and food"),func(): sim.policy=p; sim.record("A divine decree",p+" adopted by Riverhaven."); toast("Riverhaven adopted "+p+"."); show_policies(),col)
 button("Order settlement evacuation",func(): sim.evacuate(); close_modal(); toast("Evacuation ordered."),col)
 paragraph("Next era: "+(sim.era_requirement() if not sim.era_requirement().is_empty() else "Requirements met. Advance from Civilization → Research."),col)
func show_overlays() -> void:
 var col=open_modal("See beneath the surface")
 for overlay in ["Natural","Flood risk","Temperature"]:
  var o=overlay; button(o,func(): world.overlay=o; world.rebuild_terrain(); world.rebuild_globe(); close_modal(); toast(o+" overlay enabled."),col)
 paragraph("Flood risk marks land below the storm's peak river level. Temperature shows elevation's cooling effect. Raised terrain changes these same live cells.",col)
func show_climate() -> void:
 var col=open_modal("The living climate")
 paragraph("WEATHER NOW\n"+sim.weather+"\nLocal temperature: %.1f °C\n\nLONG-TERM HEAT TREND\n%+.3f °C relative to baseline. Updated once each season (10 days).\nIndustry adds heat; forests and wind power remove it."%[sim.temperature,sim.heat],col)
 for i in sim.climate_history.size(): label("Season %d     %+.3f °C"%[i+1,sim.climate_history[i]],14,INK,col)
 button("Turn the wind",func(): toast(sim.power("wind",target.x,target.z)); close_modal(),col)
func show_sandbox() -> void:
 var col=open_modal("Divine authority")
 paragraph("Mode: "+("SANDBOX" if sim.sandbox else "CHALLENGE")+". Sandbox allows free miracles and continued play after extinction.",col)
 button("Switch to "+("Challenge" if sim.sandbox else "Sandbox"),func(): sim.sandbox=not sim.sandbox; show_sandbox(); populate_tray(); update_hud(),col)
 if sim.sandbox:
  button("Create 100 grain & 100 timber",func(): sim.grain+=100; sim.wood+=100; toast("Stores replenished."); update_hud(),col)
  button("Rule "+("Cedar Camp" if sim.active_faction==0 else "Riverhaven"),func(): sim.active_faction=1-sim.active_faction; toast("New lives you create belong to "+("Cedar Camp" if sim.active_faction==1 else "Riverhaven")+"."); show_sandbox(),col)
  button("Advance one day (simulation runs)",func():
   var was_paused=sim.paused; sim.paused=false
   for i in Simulation.DAY: sim.step()
   sim.paused=was_paused; world.sync(); update_hud(); close_modal(); toast("One day has passed. Check your people and the river."),col)
  button("Restore every life",func():
   sim.release()
   for p in sim.people: sim.release_cargo(p); p.alive=true; p.health=100; p.hunger=0; p.task="idle"; p.path=[]; p.queue=[]
   world.sync(); update_hud(); close_modal(); toast("All your people live again."),col)
func show_menu() -> void:
 var col=open_modal("Worldkeeper")
 paragraph("Godot 4.6.3 · River Test · Seed %d\nAutosave every 60 seconds; previous good save retained."%sim.seed_value,col)
 button("Save world",func(): toast("World saved." if sim.save_world() else "Save failed; previous save preserved."); close_modal(),col)
 button("Load world",func():
  if sim.load_world(): rebuild_world(); toast("Your world has been restored.")
  else: toast("No valid save or backup found.")
  close_modal(),col)
 button("Pause & advance exactly one tick",func():
  sim.paused=false; sim.step(); sim.paused=true; world.sync(); update_hud(); toast("Advanced to tick %d."%sim.tick),col)
 button("Graphics: "+("HIGH" if high_quality else "BATTERY"),func():
  high_quality=not high_quality; sunlight.shadow_enabled=high_quality; get_viewport().msaa_3d=Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED; show_menu(),col)
 button("Reduced camera motion: "+("ON" if reduced_motion else "OFF"),func(): reduced_motion=not reduced_motion; show_menu(),col)
 button("High contrast: "+("ON" if high_contrast else "OFF"),func():
  high_contrast=not high_contrast
  for p in [objectives_panel,inspector_panel]: p.add_theme_stylebox_override("panel",style(Color("071b17") if high_contrast else Color(0.055,0.12,0.115,0.94)))
  show_menu(),col)
 button("Ambient sound: "+("ON" if audio_on else "OFF"),func(): audio_on=not audio_on; audio_player.playing=audio_on; show_menu(),col)
 var volume=HSlider.new(); volume.min_value=-48; volume.max_value=-6; volume.value=audio_volume; volume.custom_minimum_size.y=36; volume.value_changed.connect(func(v): audio_volume=v; audio_player.volume_db=v); col.add_child(volume)
 button("How to play",show_help,col)
 button("Restart same seed…",func():
  var confirm=open_modal("Begin again?"); paragraph("This replaces the current world. Save first if you want to return to it.",confirm)
  button("Restart River Test",func(): sim=Simulation.new(); sim.setup(); selected=-1; rebuild_world(); close_modal(); toast("The same twelve lives. A new chance."),confirm),col)
 button("New seeded world…",show_seed_picker,col)
 button("Credits & scope",show_credits,col)
func show_seed_picker() -> void:
 var col=open_modal("A new world")
 paragraph("Enter a whole-number seed. River Test geography is stable; seed changes vegetation and random event streams. Current unsaved progress will be replaced.",col)
 var field=LineEdit.new(); field.text=str(sim.seed_value); field.custom_minimum_size.y=48; col.add_child(field)
 button("Create world from seed",func():
  if not field.text.is_valid_int(): toast("Enter a valid whole number."); return
  var value=int(field.text); sim=Simulation.new(); sim.setup(value); selected=-1; rebuild_world(); close_modal(); toast("World created with seed %d."%value),col)
func show_credits() -> void:
 var col=open_modal("Made for your imagination")
 paragraph("WORLDKEEPER · Original procedural art, code, UI and sound. Fonts: Inter and Cormorant Garamond, SIL Open Font License. Broad genre inspiration: Crytivo's The Universim. No game assets or code copied.",col)
 paragraph("This is a playable River Test foundation, not a complete commercial civilization simulation. Globe view is an overview of the live terrain; local control returns through Planet. Generations, full wars, orbital colonization and advanced climate systems remain future work. Android performance depends on your device.",col)
func rebuild_world() -> void:
 remove_child(world); world.queue_free(); world=View.new(); add_child(world); world.setup(sim); world.selected=selected; mode="inspect"; update_camera(); update_hud(); update_inspector(); populate_tray()
func toggle_pause() -> void:
 sim.paused=not sim.paused; update_hud()
func cycle_speed() -> void:
 speed=4 if speed==1 else 16 if speed==4 else 1; speed_button.text=str(speed)+"×"
func toggle_globe() -> void:
 world.set_globe(not world.globe_mode); zoom=38 if world.globe_mode else 33; update_camera(); toast("Live planet overview. Return to local view to command people." if world.globe_mode else "Back to Riverhaven.")
func screen_to_world(screen: Vector2) -> Vector3:
 var origin=camera.project_ray_origin(screen); var ray=camera.project_ray_normal(screen)
 var hit=Plane(Vector3.UP,0.3).intersects_ray(origin,ray)
 if hit==null: return Vector3.ZERO
 return hit
func world_tap(screen: Vector2) -> void:
 if is_instance_valid(modal): return
 if world.globe_mode: toast("Tap ◎ Planet to return to local control."); return
 var pos=screen_to_world(screen); brush_point=Vector2(pos.x,pos.z)
 if mode.begins_with("build:"):
  toast(sim.place(mode.trim_prefix("build:"),pos.x,pos.z)); world.sync(); update_hud(); return
 if mode.begins_with("order:") or mode.begins_with("queue:"):
  toast(sim.order(selected,mode.split(":")[1],pos.x,pos.z,mode.begins_with("queue:"))); mode="inspect"; update_inspector(); return
 if mode=="lift": toast(sim.lift(selected,pos.x,pos.z)); mode="inspect"; world.sync(); update_inspector(); return
 if Rules.POWERS.has(mode):
  preview_power(mode,pos.x,pos.z); return
 var best=-1; var distance=34.0
 for p in sim.people:
  var point=Vector3(p.x,sim.elevation(p.x,p.z)+0.3,p.z)
  var d=camera.unproject_position(point).distance_to(screen)
  if d<distance: distance=d; best=p.id
 if best>=0: select_person(best); return
 for b in sim.buildings:
  if Vector2(b.x-pos.x,b.z-pos.z).length()<1.4:
   var col=open_modal(Rules.BUILDINGS[b.kind].title)
   paragraph("Health: %d%%\nConstruction: %d%%\n%s"%[b.health,int(100*b.work/Rules.BUILDINGS[b.kind].work),"Operational" if b.complete else "Workers are travelling to this foundation."],col)
   if not b.complete:
    var id=b.id; button("Cancel & return materials",func(): toast(sim.cancel_building(id)); close_modal(); world.sync(); update_hud(),col)
   return
 var c=sim.cells[sim.cell_at(pos.x,pos.z)]
 toast("Cell %d · Elevation %.2f m · %s · Local solar time %02d:00"%[c.id,c.e,"Flooded" if c.e<sim.flood else "Forest" if c.forest else "Dry ground",posmod(6+int(float(sim.tick)/Simulation.DAY*24)+int(pos.x/(Simulation.W*Simulation.CELL)*24),24)])
func preview_power(kind: String,x: float,z: float) -> void:
 var rule=Rules.POWERS[kind]; var count=0; var residents=0
 for c in sim.cells:
  if sim.position(c.id).distance_to(Vector2(x,z))<=rule.radius: count+=1
 for p in sim.people:
  if p.alive and Vector2(p.x-x,p.z-z).length()<rule.radius: residents+=1
 world.show_brush(x,z,rule.radius)
 var col=open_modal(rule.title)
 paragraph("AFFECTED AREA\n%d terrain cells · %d living people\nCost: %s\n\n%s"%[count,residents,"Free in sandbox" if sim.sandbox else str(rule.cost)+" faith","DANGER: this power can injure or kill people, destroy vegetation, or damage homes. Your world keeps these consequences." if kind in ["fire","lightning","quake","lower"] else "This miracle changes the live world. Rain puts out fires but adds water; raised earth can protect a route."],col)
 button("Confirm "+rule.title,func():
  toast(sim.power(kind,x,z,true)); close_modal(); world.rebuild_terrain(); world.rebuild_vegetation(); world.sync(); update_hud(); update_inspector(); world.brush.visible=false, col)
 button("Cancel miracle",func(): close_modal(); world.brush.visible=false,col)
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed:
  match event.keycode:
   KEY_SPACE: toggle_pause()
   KEY_TAB: toggle_globe()
   KEY_ESCAPE: mode="inspect"; world.brush.visible=false; close_modal(); preview_label.text="Drag to explore  ·  Pinch to zoom  ·  Tap a person to inspect"
   KEY_E:
    if sim.possessed>=0 and not sim.paused: sim.wood+=1; toast("Gathered one timber.")
 if event is InputEventScreenTouch:
  if event.pressed:
   touch_points[event.index]=event.position
   if touch_points.size()==1: drag_start=event.position; dragging=false
   if touch_points.size()==2: pinch_distance=touch_points.values()[0].distance_to(touch_points.values()[1]); dragging=true
  else:
   touch_points.erase(event.index)
   if touch_points.is_empty() and not dragging: world_tap(event.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag:
  touch_points[event.index]=event.position
  if touch_points.size()==2:
   var dist=touch_points.values()[0].distance_to(touch_points.values()[1])
   if pinch_distance>0: zoom=clampf(zoom*pinch_distance/maxf(1,dist),10,72); update_camera()
   pinch_distance=dist
  else:
   if event.position.distance_to(drag_start)>8: dragging=true
   if dragging: pan_camera(event.relative)
 elif event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=clampf(zoom-2,10,72); update_camera()
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=clampf(zoom+2,10,72); update_camera()
  elif event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed: pointer_down=true; dragging=false; drag_start=event.position
   else:
    if pointer_down and not dragging: world_tap(event.position)
    pointer_down=false
 elif event is InputEventMouseMotion:
  if event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
   azimuth-=event.relative.x*0.006; pitch=clampf(pitch+event.relative.y*0.004,0.3,1.3); update_camera()
  elif pointer_down:
   if event.position.distance_to(drag_start)>7: dragging=true
   if dragging: pan_camera(event.relative)
  elif Rules.POWERS.has(mode) and not world.globe_mode:
   var pos=screen_to_world(event.position); world.show_brush(pos.x,pos.z,Rules.POWERS[mode].radius)
func pan_camera(relative: Vector2) -> void:
 if is_instance_valid(modal): return
 if world.globe_mode: world.globe.rotation.y+=relative.x*0.006
 elif not reduced_motion:
  var right=camera.global_basis.x; var forward=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
  target-=right*relative.x*zoom/900+forward*relative.y*zoom/900
  target.x=clampf(target.x,-38,38); target.z=clampf(target.z,-18,18); update_camera()
func _process(delta: float) -> void:
 if world==null: return
 total_frames+=1; total_frame_time+=delta
 accumulator+=minf(delta,0.25)*speed
 var stepped=false; var steps=0
 while accumulator>=1.0 and steps<100:
  accumulator-=1.0; steps+=1
  # One fixed world-second per real second at 1×; a day lasts eight minutes.
  sim.step(); stepped=true
 if stepped:
  world.sync()
  update_hud()
  if sim.tick%5==0 and selected>=0 and not is_instance_valid(modal): update_inspector()
 world.animate(delta)
 var was_showing_toast=toast_timer>0
 toast_timer-=delta
 if was_showing_toast and toast_timer<=0: update_hud()
 move_pad.visible=sim.possessed>=0
 if sim.possessed>=0 and not sim.paused:
  var movement=hold_direction
  if Input.is_physical_key_pressed(KEY_W): movement.y-=1
  if Input.is_physical_key_pressed(KEY_S): movement.y+=1
  if Input.is_physical_key_pressed(KEY_A): movement.x-=1
  if Input.is_physical_key_pressed(KEY_D): movement.x+=1
  if movement.length()>0:
   var right=Vector2(cos(azimuth),-sin(azimuth)); var forward=Vector2(sin(azimuth),cos(azimuth))
   var direction=(right*movement.x+forward*movement.y).normalized()*delta*2.5
   sim.manual_move(direction.x,direction.y); world.sync()
 autosave_elapsed+=delta
 if autosave_elapsed>=60: autosave_elapsed=0; sim.save_world()
 if audio_on: fill_audio()
func setup_audio() -> void:
 audio_player=AudioStreamPlayer.new(); add_child(audio_player); audio_player.volume_db=audio_volume
 var generator=AudioStreamGenerator.new(); generator.mix_rate=22050; generator.buffer_length=0.25; audio_player.stream=generator
func fill_audio() -> void:
 var playback=audio_player.get_stream_playback()
 if playback==null: return
 var frames=mini(playback.get_frames_available(),6000)
 for i in frames:
  var sample=sin(audio_phase*TAU*130.81)*0.12+sin(audio_phase*TAU*196.0)*0.06+sin(audio_phase*TAU*261.63)*0.03
  sample*=0.55+sin(audio_phase*0.31)*0.15
  playback.push_frame(Vector2(sample,sample)); audio_phase+=1.0/22050
func run_smoke() -> void:
 select_person(sim.people[0].id)
 var p=sim.people[0]
 assert(sim.order(p.id,"move",-9,2).contains("move"))
 assert(sim.place("storehouse",-2,-2).begins_with("Construction"))
 assert(sim.possess(p.id).begins_with("You are"))
 sim.manual_move(0.1,0); sim.release()
 sim.power("raise",5,0,true)
 world.rebuild_terrain(); world.rebuild_vegetation(); world.sync()
 assert(sim.save_world("user://smoke.json"))
 assert(sim.load_world("user://smoke.json"))
 show_diplomacy(); close_modal(); show_menu(); close_modal()
 print("UI_SMOKE_PASS: selection, orders, construction, possession, terrain, save/load, menus")
 await get_tree().create_timer(2).timeout
 print("FRAME_SAMPLE: %d frames, %.2f ms average (includes startup; not Android benchmark)"%[total_frames,total_frame_time/maxi(1,total_frames)*1000])
 if DisplayServer.get_name()!="headless":
  var path="res://builds/worldkeeper-preview.png"
  get_viewport().get_texture().get_image().save_png(path)
  print("SCREENSHOT: "+path)
 get_tree().quit()

func find_button(root: Node,text: String) -> Button:
 for child in root.get_children():
  if child.is_queued_for_deletion(): continue
  if child is Button and child.text.begins_with(text) and child.is_visible_in_tree(): return child
  var found=find_button(child,text)
  if found!=null: return found
 return null
func input_click(point: Vector2) -> void:
 point=get_viewport().get_final_transform()*point
 var motion=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; Input.parse_input_event(motion)
 await get_tree().process_frame
 var press=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.position=point; press.global_position=point; press.pressed=true; Input.parse_input_event(press)
 await get_tree().process_frame
 var release_event=InputEventMouseButton.new(); release_event.button_index=MOUSE_BUTTON_LEFT; release_event.position=point; release_event.global_position=point; release_event.pressed=false; Input.parse_input_event(release_event)
 await get_tree().process_frame
func input_button(text: String) -> void:
 var b=find_button(ui,text)
 assert(b!=null,"Missing visible button: "+text)
 var parent_node=b.get_parent()
 while parent_node!=null:
  if parent_node is ScrollContainer:
   var bottom=b.get_global_rect().end.y
   if bottom>parent_node.get_global_rect().end.y: parent_node.scroll_vertical+=int(bottom-parent_node.get_global_rect().end.y+10)
  parent_node=parent_node.get_parent()
 await get_tree().process_frame
 print("INPUT: ",text," at ",b.get_global_rect())
 await input_click(b.get_global_rect().get_center())
 await get_tree().process_frame
func run_input_smoke() -> void:
 await get_tree().process_frame
 if mobile_ui:
  await input_button("People"); await input_button("Amara")
 else: await input_button("Meet Amara")
 assert(selected==sim.people[0].id)
 await input_button("Give or queue an order" if mobile_ui else "Command")
 await input_button("Move ·")
 assert(mode=="order:move")
 await input_click(camera.unproject_position(Vector3(-9,0.3,2)))
 assert(sim.ordered and sim.person(selected).task=="move")
 if mobile_ui: await input_button("People"); await input_button("Amara")
 await input_button("Possess")
 assert(sim.possessed==selected)
 if mobile_ui: await input_button("People"); await input_button("Amara")
 await input_button("Release")
 assert(sim.possessed==-1)
 await input_button("Settlement")
 await input_button("Storehouse")
 await input_click(camera.unproject_position(Vector3(-2,0.3,-2)))
 assert(sim.buildings.back().kind=="storehouse")
 await input_button("Miracles")
 await input_button("Rain")
 await input_click(camera.unproject_position(Vector3(-4,0.3,1)))
 assert(is_instance_valid(modal))
 await input_button("Confirm Rain")
 assert(sim.weather=="Divine rainfall")
 var key=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=true; Input.parse_input_event(key)
 await get_tree().process_frame
 assert(sim.paused)
 var tick_before=sim.tick
 await get_tree().process_frame
 assert(sim.tick==tick_before)
 await input_button("☰")
 await input_button("Save world")
 assert(FileAccess.file_exists("user://worldkeeper.json"))
 mode="inspect"
 var zoom_before=zoom
 await input_touch(0,Vector2(650,420),true)
 await input_touch(1,Vector2(800,420),true)
 var pinch=InputEventScreenDrag.new(); pinch.index=1; pinch.position=get_viewport().get_final_transform()*Vector2(900,420); pinch.relative=Vector2(100,0); Input.parse_input_event(pinch)
 await get_tree().process_frame
 await input_touch(1,Vector2(900,420),false)
 await input_touch(0,Vector2(650,420),false)
 assert(zoom<zoom_before)
 print("INPUT_SMOKE_PASS: real pointer/key/touch events select, order, possess/release, build, preview/confirm rain, pause, save, and pinch zoom")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://builds/worldkeeper-mobile-preview.png" if mobile_ui else "res://builds/worldkeeper-input-preview.png")
 get_tree().quit()

func input_touch(index: int,point: Vector2,pressed: bool) -> void:
 var touch=InputEventScreenTouch.new(); touch.index=index; touch.position=get_viewport().get_final_transform()*point; touch.pressed=pressed
 Input.parse_input_event(touch)
 await get_tree().process_frame

func _notification(what: int) -> void:
 if sim==null or sim.cells.is_empty(): return
 if what==MainLoop.NOTIFICATION_APPLICATION_PAUSED: sim.save_world()
 elif what==Node.NOTIFICATION_WM_GO_BACK_REQUEST:
  if ui==null: return
  if is_instance_valid(modal): close_modal()
  else: show_menu()
