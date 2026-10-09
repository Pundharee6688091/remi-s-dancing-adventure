extends SceneTree
## Regenerates the dialogue translation CSVs.
##
## This is what Dialogic's Settings -> Translation -> "Update CSV files" button
## does. That button lives in the editor UI and reaches into the open timeline
## editor, so it cannot be scripted; this does the same work against the same
## Dialogic classes, which keeps the translation ids and key format identical.
##
## Run it from the project root after adding or editing dialogue:
##   godot --headless --path . --script res://tools/gen_vn_translations.gd
## then open the project once so Godot imports the CSVs it wrote.

const EXTRA_LOCALES := ["th"]

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true


func _run() -> void:
	var orig := String(ProjectSettings.get_setting("dialogic/translation/original_locale", "en"))
	var folder := String(ProjectSettings.get_setting("dialogic/translation/translation_folder", "res://"))
	var per_timeline := int(ProjectSettings.get_setting("dialogic/translation/file_mode", 0)) == 1
	var written: Array[String] = []

	var shared: DialogicCsvFile = null
	if not per_timeline:
		shared = DialogicCsvFile.new(folder.path_join("dialogic_timeline_translations.csv"), orig, false)

	for path: String in DialogicResourceUtil.list_resources_of_type(".dtl"):
		var timeline: DialogicTimeline = load(path)
		if timeline == null or timeline.events.size() == 0:
			print("  skipped (empty): ", path)
			continue
		timeline.process()

		var csv := shared
		if per_timeline:
			var who := path.get_file().trim_suffix(".dtl")
			csv = DialogicCsvFile.new(folder.path_join("dialogic_%s_translation.csv" % who), orig, false)

		csv.collect_lines_from_timeline(timeline)

		# Events only get an id the first time; saving writes those ids back.
		timeline.set_meta("timeline_not_saved", true)
		ResourceSaver.save(timeline, path)

		if per_timeline:
			csv.update_csv_file_on_disk()
			written.append(csv.used_file_path)
		print("  %-34s %d new, %d existing" % [path.get_file(), csv.new_rows, csv.updated_rows])

	if shared != null:
		shared.update_csv_file_on_disk()
		written.append(shared.used_file_path)

	# Speaker names are translated separately from the lines they say.
	var names := DialogicCsvFile.new(folder.path_join("dialogic_character_translations.csv"), orig, false)
	var all := {}
	for path: String in DialogicResourceUtil.list_resources_of_type(".dch"):
		var character: DialogicCharacter = load(path)
		if character == null:
			continue
		all[character.get_set_translation_id()] = character
		ResourceSaver.save(character)
	names.collect_lines_from_characters(all)
	names.update_csv_file_on_disk()
	written.append(names.used_file_path)
	print("  %-34s %d characters" % ["character names", all.size()])

	for file in written:
		_add_locale_columns(file)
	# Deliberately no ProjectSettings.save(). A name that fails to resolve
	# leaves a throwaway character in Dialogic's in-memory directory, and
	# saving would write that object into project.godot and corrupt it.
	print("Wrote %d csv files to %s" % [written.size(), folder])
	quit()


## Gives every file a column per extra locale and seeds any empty cell with the
## original text.
##
## The seeding matters: Godot's CSV importer skips a column that is empty all
## the way down, so an untouched locale would never produce a .translation file
## and the wiring would look broken until the first line was translated. A cell
## left as the English reads as English in game, which is what an empty cell
## would have fallen back to anyway.
##
## Dialogic keeps columns it does not recognise when it rewrites a file, so a
## translated cell survives the next run of this script.
func _add_locale_columns(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var rows: Array[PackedStringArray] = []
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		rows.append(row)
	f.close()
	if rows.is_empty():
		return

	var header := rows[0]
	var columns: Array[int] = []
	for locale in EXTRA_LOCALES:
		var at := Array(header).find(locale)
		if at == -1:
			at = header.size()
			header.append(locale)
		columns.append(at)
	rows[0] = header

	var width := header.size()
	for i in range(1, rows.size()):
		var row := rows[i]
		while row.size() < width:
			row.append("")
		# column 1 is the original locale
		for at in columns:
			if row[at].is_empty() and row.size() > 1:
				row[at] = row[1]
		rows[i] = row

	var out := FileAccess.open(path, FileAccess.WRITE)
	for row in rows:
		out.store_csv_line(row)
	out.close()
