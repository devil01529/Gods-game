extends SceneTree
func _initialize() -> void:
 var s=WorldSimulation.new();s.setup();s.reproduction="Paused"
 assert(s.place("storehouse",-1,-1).contains("started"))
 assert(s.place("levee",3,0).contains("started"))
 for i in 600:s.step()
 assert(s.research().contains("SETTLEMENT"))
 s.wood+=100 # Supply fixture; construction, paths, work and research still run normally.
 assert(s.place("market",-11,6).contains("started"))
 assert(s.place("workshop",1,4).contains("started"))
 s.diplomacy("trade");s.diplomacy("treaty")
 for i in 800:s.step()
 assert(s.research().contains("INDUSTRY"))
 assert(s.place("windmill",-13,-5).contains("started"))
 for i in 3500:s.step()
 assert(s.research().contains("PLANETARY"))
 s.wood+=100
 assert(s.place("observatory",1,-5).contains("started"))
 for i in 800:s.step()
 assert(s.has_building("observatory"))
 assert(s.alive_count()==12)
 # Isolate the year counter gate without requiring a 5.3-hour wall-clock test.
 s.supplied_ticks=WorldSimulation.DAY*40-10
 for i in 10:s.step()
 assert(s.outcome=="Stewardship complete")
 print("PROGRESSION_PASS: four eras, real crews/construction/trade/research, observatory; year-boundary counter fixture; survivors=%d"%s.alive_count())
 quit()
