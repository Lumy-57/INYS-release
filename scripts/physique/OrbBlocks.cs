// Chapitre Compagnie : pierres cachées ("i").
// Invisibles et traversables dans le noir. Quand la petite orbe passe près d'elles,
// elles apparaissent et portent le fantôme, puis s'effacent peu après son départ.
// Une pierre déjà vue garde un contour très pâle : on se souvient d'où elle était.
// Le fantôme seul n'en devine qu'autour de ses pieds : c'est l'orbe qui voit loin.
// On les traverse par en dessous (on ne s'y cogne jamais la tête) et, comme les blocs
// de phase, une pierre ne réapparaît jamais sur le fantôme.
using Godot;

namespace Lumignon;

public partial class OrbBlocks : Node2D
{
	const int Tile = 16;
	const float Reach = 40f;       // distance orbe-pierre à laquelle la pierre apparaît
	const float ReachGhost = 22f;  // idem autour du fantôme
	const float Grace = 0.9f;      // durée pendant laquelle elle reste après le passage de l'orbe

	public Godot.Collections.Array Cells = new();  // Vector2i
	public Player Player;
	public Node2D Orb;  // hint_orb.gd : lit_points() donne l'orbe puis le fantôme

	Rect2[] rects;
	CollisionShape2D[] shapes;
	bool[] solid;
	float[] left;   // temps restant avant de s'effacer
	float[] shown;  // 0 → 1, pour le fondu
	bool[] seen;
	float t;

	public override void _Ready()
	{
		// Lisibles même hors de la lumière du fantôme : c'est l'orbe qui les montre
		Blocks.Unshaded(this);
		int n = Cells.Count;
		rects = new Rect2[n];
		shapes = new CollisionShape2D[n];
		solid = new bool[n];
		left = new float[n];
		shown = new float[n];
		seen = new bool[n];
		for (int i = 0; i < n; i++)
		{
			Vector2 c = Cells[i].AsVector2I();
			rects[i] = new Rect2(c * Tile, new Vector2(Tile, Tile));
			var cs = Blocks.AddSolid(this, rects[i]);
			cs.Disabled = true;
			cs.OneWayCollision = true;
			shapes[i] = cs;
		}
	}

	public void Reset()
	{
		for (int i = 0; i < left.Length; i++)
			left[i] = 0f;
	}

	public override void _PhysicsProcess(double deltaD)
	{
		float delta = (float)deltaD;
		var lights = Orb != null ? Orb.Call("lit_points").AsGodotArray() : new Godot.Collections.Array();
		var bodyRect = Player.BodyRect().Grow(-0.5f);
		for (int i = 0; i < rects.Length; i++)
		{
			var r = rects[i];
			for (int j = 0; j < lights.Count; j++)
			{
				Vector2 p = lights[j].AsVector2();
				var q = new Vector2(Mathf.Clamp(p.X, r.Position.X, r.End.X), Mathf.Clamp(p.Y, r.Position.Y, r.End.Y));
				if (q.DistanceTo(p) < (j == 0 ? Reach : ReachGhost))
				{
					left[i] = Grace;
					seen[i] = true;
					break;
				}
			}
			left[i] = Mathf.Max(left[i] - delta, 0f);
			bool on = left[i] > 0f;
			if (on && !solid[i] && !Player.Dead && r.Intersects(bodyRect))
				on = false;
			if (on != solid[i])
			{
				solid[i] = on;
				Blocks.SetSolid(shapes[i], on);
			}
		}
	}

	public override void _Process(double deltaD)
	{
		float delta = (float)deltaD;
		t += delta;
		for (int i = 0; i < rects.Length; i++)
			shown[i] = Mathf.MoveToward(shown[i], solid[i] ? 1f : 0f, delta * (solid[i] ? 6f : 2.5f));
		QueueRedraw();
	}

	public override void _Draw()
	{
		var pale = new Color(0.7f, 0.7f, 0.75f, 0.22f);
		for (int i = 0; i < rects.Length; i++)
		{
			var r = rects[i];
			float k = shown[i];
			if (k > 0f)
			{
				DrawRect(r, new Color(0.92f, 0.92f, 0.95f, 0.85f * k));
				DrawRect(r.Grow(-3), new Color(0.7f, 0.7f, 0.76f, 0.85f * k));
				// Un petit éclat qui court sur la pierre
				float x = r.Position.X + Mathf.PosMod(t * 18f + r.Position.Y * 0.7f, Tile);
				DrawRect(new Rect2(x, r.Position.Y + 1, 1, 2), new Color(1, 1, 1, 0.9f * k));
			}
			else if (seen[i])
				Blocks.Dotted(this, r, pale, false);
			if (seen[i] && k > 0f && k < 1f)
				Blocks.Dotted(this, r, new Color(pale, 0.22f * (1f - k)), false);
		}
	}
}
