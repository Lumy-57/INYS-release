// Blocs rythmés, sur un métronome commun à tout le niveau.
// "1" : solides pendant la première moitié du cycle. "2" : pendant la seconde.
// Un bloc clignote juste avant de disparaître ; un bloc absent se remplit à mesure qu'il revient.
// Comme les blocs de phase, un bloc qui devrait réapparaître sur le fantôme attend qu'il en sorte.
// La musique se cale sur ce métronome (music.gd lit T, et reprend PERIOD et WARN).
using Godot;
using System.Collections.Generic;

namespace Lumignon;

public partial class TimedBlocks : Node2D
{
	public const float Period = 2.4f;  // un cycle complet, en secondes
	public const float Warn = 0.4f;    // durée du clignotement avant disparition

	public Godot.Collections.Array Runs1 = new();  // Rect2 en pixels
	public Godot.Collections.Array Runs2 = new();
	public Player Player;
	public float T;  // temps du métronome

	class Block
	{
		public Rect2 Rect;
		public int Phase;
		public CollisionShape2D Shape;
		public bool Solid = true;
	}

	readonly List<Block> blocks = new();

	public override void _Ready()
	{
		Blocks.Unshaded(this);
		for (int phase = 0; phase < 2; phase++)
			foreach (var r in Blocks.Rects(phase == 0 ? Runs1 : Runs2))
				blocks.Add(new Block { Rect = r, Phase = phase, Shape = Blocks.AddSolid(this, r) });
		UpdateSolid(true);
	}

	// Phase active (0 ou 1) et temps écoulé dans la demi-période
	int CurrentPhase() => (int)(Mathf.PosMod(T, Period) / (Period * 0.5f));

	float InHalf() => Mathf.PosMod(T, Period * 0.5f);

	public override void _PhysicsProcess(double delta)
	{
		T += (float)delta;
		UpdateSolid(false);
	}

	void UpdateSolid(bool force)
	{
		var bodyRect = Player.BodyRect().Grow(-0.5f);
		int phase = CurrentPhase();
		foreach (var b in blocks)
		{
			bool on = b.Phase == phase;
			if (on && !b.Solid && !force && !Player.Dead && b.Rect.Intersects(bodyRect))
				on = false;
			if (on != b.Solid || force)
			{
				b.Solid = on;
				Blocks.SetSolid(b.Shape, on);
			}
		}
	}

	public override void _Process(double delta) => QueueRedraw();

	public override void _Draw()
	{
		float half = Period * 0.5f;
		float u = InHalf();
		bool warn = u > half - Warn && Mathf.PosMod(u * 10f, 1f) < 0.5f;
		foreach (var b in blocks)
		{
			var r = b.Rect;
			bool light = b.Phase == 0;
			if (b.Solid)
			{
				var fill = light ? new Color(0.75f, 0.75f, 0.75f) : new Color(0.4f, 0.4f, 0.4f);
				if (warn)
					fill = fill.Lerp(new Color(0.1f, 0.1f, 0.1f), 0.6f);
				DrawRect(r, fill);
				DrawRect(r, new Color(0.95f, 0.95f, 0.95f), false, 1f);
				ClockMarks(r, light, u / half);
			}
			else
			{
				Blocks.Dotted(this, r, new Color(0.7f, 0.7f, 0.7f, 0.45f));
				// Le bloc absent se remplit par le bas jusqu'à son retour
				float h = r.Size.Y * (u / half);
				DrawRect(new Rect2(r.Position.X + 1, r.End.Y - h, r.Size.X - 2, h), new Color(1, 1, 1, 0.08f));
			}
		}
	}

	// Un petit cadran par tuile, dont l'aiguille fait un tour par demi-période
	void ClockMarks(Rect2 r, bool light, float k)
	{
		var ink = light ? new Color(0.3f, 0.3f, 0.3f) : new Color(0.85f, 0.85f, 0.85f);
		for (float y = r.Position.Y; y < r.End.Y; y += 16f)
			for (float x = r.Position.X; x < r.End.X; x += 16f)
			{
				var c = new Vector2(x + 8, y + 8);
				DrawArc(c, 4f, 0f, Mathf.Tau, 12, ink, 1f);
				DrawLine(c, c + Vector2.Up.Rotated(k * Mathf.Tau) * 3f, ink, 1f);
			}
	}
}
