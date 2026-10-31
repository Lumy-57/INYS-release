# Au démarrage, demande à GitHub les versions publiées sur INYS-release et signale
# s'il en existe une plus récente que application/config/version.
# Silencieux en cas d'échec : hors ligne, limite de l'API, réponse illisible.
# Les releases sont publiées par plateforme (tags « V0.1.0-win », « V0.1.0-lin ») :
# on garde la plus haute version et, si possible, la release de la plateforme du joueur.
extends Node

signal found(version: String, url: String)

const API := "https://api.github.com/repos/Lumy-57/INYS-release/releases?per_page=20"
const RELEASES_PAGE := "https://github.com/Lumy-57/INYS-release/releases"

var latest := ""  # version plus récente trouvée, vide sinon
var url := ""
var http: HTTPRequest


func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(_on_completed)
	var headers := ["Accept: application/vnd.github+json"]
	# GitHub exige un User-Agent ; dans un navigateur, c'est lui qui le fournit
	if not OS.has_feature("web"):
		headers.append("User-Agent: Lumignon")
	if http.request(API, headers) != OK:
		http.queue_free()


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var releases = JSON.parse_string(body.get_string_from_utf8())
	if not releases is Array:
		return
	var current := parse_version(str(ProjectSettings.get_setting("application/config/version", "0")))
	var best := current
	var best_url := ""
	for r in releases:
		if not r is Dictionary or r.get("draft", false) or r.get("prerelease", false):
			continue
		var tag := str(r.get("tag_name", ""))
		var v := parse_version(tag)
		var cmp := compare(v, best)
		# À version égale, la release de notre plateforme passe devant
		if cmp > 0 or (cmp == 0 and best != current and _for_this_platform(tag)):
			best = v
			best_url = str(r.get("html_url", ""))
	if compare(best, current) <= 0:
		return
	latest = "%d.%d.%d" % best
	url = best_url if best_url.begins_with("https://") else RELEASES_PAGE
	found.emit(latest, url)


func open_page() -> void:
	if url != "":
		OS.shell_open(url)


# « V0.2.1-win » → [0, 2, 1]
static func parse_version(text: String) -> Array:
	var s := text.strip_edges().trim_prefix("v").trim_prefix("V").get_slice("-", 0)
	var parts := []
	for p in s.split("."):
		parts.append(p.to_int())
	while parts.size() < 3:
		parts.append(0)
	return parts


static func compare(a: Array, b: Array) -> int:
	for i in max(a.size(), b.size()):
		var x: int = a[i] if i < a.size() else 0
		var y: int = b[i] if i < b.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


static func _for_this_platform(tag: String) -> bool:
	var t := tag.to_lower()
	match OS.get_name():
		"Windows":
			return t.ends_with("-win")
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return t.ends_with("-lin")
		"macOS":
			return t.ends_with("-mac")
		"Web":
			return t.ends_with("-web")
	return false
