# Petites textures partagées : le halo des lumières et le fondu des particules.
# Appelées aussi depuis le C# (scripts/physique/Player.cs).
extends RefCounted


static func make_light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(0, 0, 0, 0))
	grad.add_point(0.25, Color(0.8, 0.8, 0.8, 1))
	grad.add_point(0.6, Color(0.25, 0.25, 0.25, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


static func fade_gradient(start: Color) -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, start)
	grad.set_color(1, Color(start.r, start.g, start.b, 0))
	return grad
