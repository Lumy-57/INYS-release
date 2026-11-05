// Blocs de carillon.
// "a" : solides au repos. "b" : solides une fois les cloches sonnées. Chaque cloche inverse les deux.
// Comme les blocs de phase, un bloc qui devrait réapparaître sur le fantôme attend qu'il en sorte.
// L'état est mémorisé à chaque bougie : après une mort, on repart de l'état de la dernière bougie.
using Godot;
using System.Collections.Generic;

namespace Lumignon;

public partial class ToggleBlocks : Node2D
{
	public Godot.Collections.Array RunsA = new();  // Rect2 en pixels
	public Godot.Collections.Array RunsB = new();
	public Player Player;
	public bool Rung;  // false : "a" solides, true : "b" solides

	class Block
	{
		public Rect2 Rect;
		public bool IsB;
		public CollisionShape2D Shape;
		public bool Solid = true;
	}

	readonly List<Block> blocks = new();
	bool saved;
	float flash;

	public override void _Ready()
	{
		Blocks.Unshaded(this);
		foreach (var r in Blocks.Rects(RunsA))
			blocks.Add(new Block { Rect = r, IsB = false, Shape = Blocks.AddSolid(this, r) });
		foreach (var r in Blocks.Rects(RunsB))
			blocks.Add(new Block { Rect = r, IsB = true, Shape = Blocks.AddSolid(this, r) });
		UpdateSolid(true);
	}

	public void Ring()
	{
		Rung = !Rung;
		flash = 1f;
	}

	public void Save() => saved = Rung;

	public void Reset()
	{
		Rung = saved;
		UpdateSolid(true);
	}

	public override void _PhysicsProcess(double delta) => UpdateSolid(false);

	void UpdateSolid(bool force)
	{
		var bodyRect = Player.BodyRect().Grow(-0.5f);
		foreach (var b in blocks)
		{
			bool on = b.IsB == Rung;
			if (on && !b.Solid && !force && !Player.Dead && b.Rect.Intersects(bodyRect))
				on = false;
			if (on != b.Solid || force)
			{
				b.Solid = on;
				Blocks.SetSolid(b.Shape, on);
			}
		}
	}

	public override void _Process(double delta)
	{
		flash = Mathf.Max(flash - (float)delta * 3f, 0f);
		QueueRedraw();
	}

	public override void _Draw()
	{
		foreach (var b in blocks)
		{
			var r = b.Rect;
			bool light = !b.IsB;
			if (b.Solid)
			{
				var fill = light ? new Color(0.78f, 0.78f, 0.78f) : new Color(0.32f, 0.32f, 0.32f);
				DrawRect(r, fill.Lerp(Colors.White, flash * 0.5f));
				DrawRect(r, new Color(0.95f, 0.95f, 0.95f), false, 1f);
				// Une petite cloche par tuile : pleine pour "a", évidée pour "b"
				for (float y = r.Position.Y; y < r.End.Y; y += 16f)
					for (float x = r.Position.X; x < r.End.X; x += 16f)
						BellMark(new Vector2(x + 8, y + 8), light);
			}
			else
				Blocks.Dotted(this, r, new Color(0.7f, 0.7f, 0.7f, 0.45f));
		}
	}

	void BellMark(Vector2 c, bool filled)
	{
		var pts = new Vector2[]
		{
			c + new Vector2(-1.5f, -4), c + new Vector2(1.5f, -4), c + new Vector2(3, 0),
			c + new Vector2(4, 3), c + new Vector2(-4, 3), c + new Vector2(-3, 0),
		};
		var dark = new Color(0.35f, 0.35f, 0.35f);
		var pale = new Color(0.85f, 0.85f, 0.85f);
		if (filled)
			DrawColoredPolygon(pts, dark);
		else
			DrawPolyline(new List<Vector2>(pts) { pts[0] }.ToArray(), pale, 1f);
		DrawRect(new Rect2(c + new Vector2(-1, 3), new Vector2(2, 2)), filled ? dark : pale);
	}
}
