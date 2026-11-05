// Outils communs aux blocs qui apparaissent et disparaissent (lumière et ombre, rythmés,
// carillon, pierres cachées) : leurs corps solides et leur contour pointillé.
using Godot;

namespace Lumignon;

public static class Blocks
{
	// Un corps solide qui couvre r, ajouté sous parent ; rend sa forme pour l'allumer et l'éteindre
	public static CollisionShape2D AddSolid(Node parent, Rect2 r, string group = null)
	{
		var body = new StaticBody2D();
		if (group != null)
			body.AddToGroup(group);
		var cs = new CollisionShape2D
		{
			Shape = new RectangleShape2D { Size = r.Size },
			Position = r.GetCenter(),
		};
		body.AddChild(cs);
		parent.AddChild(body);
		return cs;
	}

	public static void SetSolid(CollisionShape2D cs, bool on) =>
		cs.SetDeferred(CollisionShape2D.PropertyName.Disabled, !on);

	// Toujours lisibles, même loin de la lumière du fantôme
	public static void Unshaded(CanvasItem item) =>
		item.Material = new CanvasItemMaterial { LightMode = CanvasItemMaterial.LightModeEnum.Unshaded };

	// Les Rect2 d'un tableau venu du GDScript (main.gd)
	public static Rect2[] Rects(Godot.Collections.Array runs)
	{
		var list = new Rect2[runs?.Count ?? 0];
		for (int i = 0; i < list.Length; i++)
			list[i] = runs[i].AsRect2();
		return list;
	}

	// Contour pointillé d'un bloc absent
	public static void Dotted(CanvasItem ci, Rect2 r, Color c, bool sides = true)
	{
		for (float x = r.Position.X; x < r.End.X; x += 4f)
		{
			ci.DrawRect(new Rect2(x, r.Position.Y, 2, 1), c);
			if (sides)
				ci.DrawRect(new Rect2(x, r.End.Y - 1, 2, 1), c);
		}
		if (!sides)
			return;
		for (float y = r.Position.Y; y < r.End.Y; y += 4f)
		{
			ci.DrawRect(new Rect2(r.Position.X, y, 1, 2), c);
			ci.DrawRect(new Rect2(r.End.X - 1, y, 1, 2), c);
		}
	}
}
