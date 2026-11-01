extends GutTest
## Aucun autre test ne charge la présentation : une erreur de compilation y passerait inaperçue.

const DIRECTORIES: Array[String] = ["res://game/", "res://meta/", "res://services/", "res://tools/"]


func test_all_project_scripts_compile() -> void:
	for directory: String in DIRECTORIES:
		for file_name: String in DirAccess.get_files_at(directory):
			if file_name.get_extension() == "gd":
				var script: GDScript = load(directory + file_name)
				assert_true(script != null and script.can_instantiate(), directory + file_name)
	pass_test("Scripts vérifiés")
