extends SceneTree

# Bot di collaudo (opzionale): guida da solo la scena test_mountain fino in cima
# e stampa un riepilogo. Si lancia senza finestra:
#   Godot --headless --path <progetto> --fixed-fps 60 --script res://tools/validate_mountain.gd

var scene: Node
var t := 0.0
var best_idx := 0
var max_y := 0.0
var max_off := 0.0
var min_real := 99.0
var samples := 0
var sum_real := 0.0
var out_time := -1.0
var finish_time := -1.0
var connected := false
const DURATION := 90.0

func _initialize() -> void:
	scene = load("res://scenes/test_mountain.tscn").instantiate()
	root.add_child(scene)
	Input.action_press("forward")

func _physics_process(delta: float) -> bool:
	t += delta
	var v = scene.vehicle
	var road = scene.road
	if v == null or road == null:
		return false
	if not connected:
		connected = true
		road.finish_reached.connect(func(_b): finish_time = t)
	var pos: Vector3 = v.sphere.global_position
	var cl: PackedVector3Array = road.centerline
	# indice del campione piu' vicino
	var bi := best_idx
	var bd := INF
	for i in range(maxi(best_idx - 5, 0), mini(best_idx + 40, cl.size())):
		var d := Vector2(pos.x - cl[i].x, pos.z - cl[i].z).length()
		if d < bd:
			bd = d
			bi = i
	best_idx = maxi(best_idx, bi)
	max_off = maxf(max_off, bd)
	max_y = maxf(max_y, pos.y)
	if t > 3.0:
		var rs: float = v.sphere.linear_velocity.length()
		samples += 1
		sum_real += rs
		min_real = minf(min_real, rs)
	# pilota: punta a un campione 6 passi avanti
	var tgt := cl[mini(bi + 6, cl.size() - 1)]
	var f: Vector3 = v.vehicle_model.global_basis.z
	f.y = 0.0
	var to := Vector3(tgt.x - pos.x, 0.0, tgt.z - pos.z)
	var ang := f.normalized().signed_angle_to(to.normalized(), Vector3.UP)
	Input.action_release("left")
	Input.action_release("right")
	var s := clampf(absf(ang) * 2.0, 0.0, 1.0)
	if ang < -0.02:
		Input.action_press("right", s)
	elif ang > 0.02:
		Input.action_press("left", s)
	if pos.y < -3.0 and out_time < 0.0:
		out_time = t
	if finish_time >= 0.0 or t > DURATION or out_time >= 0.0:
		print("=== RISULTATO ===")
		print("riepilogo a schermo: %s | secondi per barra: %s" % [str(scene.get_node_or_null("RaceSummary") != null), str(scene.bar_time)])
		print("traguardo: %s | tempo %.1f s | progresso %d/%d campioni (%.0f%%) | quota max %.1f m | scostamento max dal centro %.1f m | v reale media %.1f min %.1f | caduto: %s" % [
			("RAGGIUNTO a %.1f s" % finish_time) if finish_time >= 0.0 else "NO", t, best_idx, cl.size() - 1, 100.0 * best_idx / (cl.size() - 1), max_y, max_off, sum_real / maxf(samples, 1), min_real, str(out_time >= 0.0)])
		quit()
	return false
