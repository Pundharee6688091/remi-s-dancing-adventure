class_name ChartParser
extends RefCounted

const BEATS_PER_MEASURE := 4.0
const FIRST_LANE_CHANNEL := 11

static func parse(path: String) -> Dictionary:
	var chart := {
		"title": "",
		"bpm": 120.0,
		"offset_ms": 0.0,
		"level": 1,
		"wave": "song.mp3",
		"notes": [],
	}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open chart: " + path)
		return chart

	for raw in f.get_as_text().split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with(";") or not line.begins_with("#"):
			continue

		var colon := line.find(":")
		if colon == -1:
			continue

		var key := line.substr(1, colon - 1).strip_edges()
		var value := line.substr(colon + 1).strip_edges()

		if key.length() == 5 and key.is_valid_int():
			_read_measure(chart, key, value)
		else:
			_read_header(chart, key, value)

	var ms_per_beat: float = 60000.0 / chart.bpm
	for n in chart.notes:
		n.t_ms = chart.offset_ms + n.beat * ms_per_beat

	chart.notes.sort_custom(func(a, b): return a.t_ms < b.t_ms)
	return chart


## How busy a chart is, which is the difficulty number the test plan asks for.
##
## Measured across the span the notes actually occupy rather than the whole
## song, because a long quiet intro would make a dense chart look easy. peak is
## the busiest single second anywhere in the chart, which is the part a player
## actually struggles with: an average of two notes a second is a different
## song depending on whether it ever reaches eight.
static func density(chart: Dictionary) -> Dictionary:
	var notes: Array = chart.get("notes", [])
	var n := notes.size()
	if n == 0:
		return {"notes": 0, "span_s": 0.0, "nps": 0.0, "peak_nps": 0}
	var span: float = maxf((float(notes[n - 1].t_ms)
		- float(notes[0].t_ms)) / 1000.0, 0.001)
	# The notes are already sorted by time, so one pass with a window that
	# only ever moves forward finds the busiest second.
	var peak := 0
	var tail := 0
	for head in n:
		while float(notes[head].t_ms) - float(notes[tail].t_ms) > 1000.0:
			tail += 1
		peak = maxi(peak, head - tail + 1)
	return {"notes": n, "span_s": span, "nps": float(n) / span,
		"peak_nps": peak}


static func _read_header(chart: Dictionary, key: String, value: String) -> void:
	match key.to_upper():
		"TITLE":  chart.title = value
		"BPM":    chart.bpm = float(value)
		"OFFSET": chart.offset_ms = float(value)
		"LEVEL":  chart.level = int(value)
		"WAVE":   chart.wave = value


static func _read_measure(chart: Dictionary, key: String, value: String) -> void:
	var measure := int(key.substr(0, 3))
	var lane := int(key.substr(3, 2)) - FIRST_LANE_CHANNEL
	if lane < 0 or lane > 3:
		return

	var data := value.replace(" ", "")
	var slots := data.length()
	if slots == 0:
		return

	for i in slots:
		if data[i] == "0":
			continue
		var beat: float = measure * BEATS_PER_MEASURE \
			+ (float(i) / slots) * BEATS_PER_MEASURE
		chart.notes.append({"beat": beat, "lane": lane, "t_ms": 0.0})
