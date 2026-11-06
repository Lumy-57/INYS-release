// Blocs de phase.
// "L" (lumière) : solides seulement quand le fantôme brille, c'est-à-dire quand son dash est disponible.
// "O" (ombre) : solides seulement quand le fantôme est éteint, après avoir utilisé son dash.
// Un bloc qui devrait réapparaître sur le fantôme attend qu'il en sorte : jamais d'écrasement.
using Godot;

namespace Lumignon;

public partial class PhaseBlocks : Node2D
{
	public string Kind = "L";
	public Godot.Collections.Array Runs = new();  // Rect2 en pixels, une par rangée horizontale de tuiles
	public Player Player;

	Rect2[] runs;
	CollisionShape2D[] shapes;
	bool[] solid;

	bool Light => Kind == "L";

	public override void _Ready()
	{
		Blocks.Unshaded(this);
		runs = Blocks.Rects(Runs);
		shapes = new CollisionShape2D[runs.Length];
		solid = new bool[runs.Length];
		for (int i = 0; i < runs.Length; i++)
		{
			// L'ombre porte le fantôme sans recharger son dash (Player.OnSolidGround)
			shapes[i] = Blocks.AddSolid(this, runs[i], Light ? null : "shadow");
			solid[i] = true;
		}
		UpdateSolid(true);
	}

	public override void _PhysicsProcess(double delta) => UpdateSolid(false);

	void UpdateSolid(bool force)
	{
		bool want = Light ? Player.Glowing() : !Player.Glowing();
		var bodyRect = Player.BodyRect().Grow(-0.5f);
		for (int i = 0; i < runs.Length; i++)
		{
			bool on = want;
			if (on && !solid[i] && !Player.Dead && runs[i].Intersects(bodyRect))
				on = false;
			if (on != solid[i] || force)
			{
				solid[i] = on;
				Blocks.SetSolid(shapes[i], on);
			}
		}
	}

	public override void _Process(double delta) => QueueRedraw();

	public override void _Draw()
	{
		for (int i = 0; i < runs.Length; i++)
		{
			var r = runs[i];
			if (Light)
			{
				if (solid[i])
				{
					DrawRect(r, new Color(0.8f, 0.8f, 0.8f));
					DrawRect(r.Grow(-3), new Color(0.55f, 0.55f, 0.55f));
				}
				else
					Blocks.Dotted(this, r, new Color(0.6f, 0.6f, 0.6f, 0.5f));
			}
			else if (solid[i])
			{
				DrawRect(r, new Color(0.12f, 0.12f, 0.12f));
				// Hachures diagonales, tuile par tuile
				var hatch = new Color(0.7f, 0.7f, 0.7f);
				for (float y = r.Position.Y; y < r.End.Y; y += 16f)
					for (float x = r.Position.X; x < r.End.X; x += 16f)
					{
						DrawLine(new Vector2(x, y + 16), new Vector2(x + 16, y), hatch, 1f);
						DrawLine(new Vector2(x, y + 8), new Vector2(x + 8, y), hatch, 1f);
						DrawLine(new Vector2(x + 8, y + 16), new Vector2(x + 16, y + 8), hatch, 1f);
					}
				DrawRect(r, new Color(0.85f, 0.85f, 0.85f), false, 1f);
			}
			else
				Blocks.Dotted(this, r, new Color(0.45f, 0.45f, 0.45f, 0.4f));
		}
	}
}
