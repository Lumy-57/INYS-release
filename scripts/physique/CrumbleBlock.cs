// Pierre fissurée : tremble dès que le fantôme la touche, s'effondre, puis revient.
using Godot;

namespace Lumignon;

public partial class CrumbleBlock : StaticBody2D
{
	[Signal] public delegate void CrumbledEventHandler(CrumbleBlock block);

	enum State { Idle, Shaking, Gone }

	public float ShakeTime = 0.45f;  // secondes de tremblement avant la chute
	public float GoneTime = 2f;      // secondes avant le retour
	public Rect2 Rect;               // en pixels, coordonnées du niveau
	public Player Player;

	State state = State.Idle;
	float timer;
	CollisionShape2D shape;

	public override void _Ready()
	{
		shape = new CollisionShape2D
		{
			Shape = new RectangleShape2D { Size = Rect.Size },
			Position = Rect.GetCenter(),
		};
		AddChild(shape);
	}

	public void Reset()
	{
		state = State.Idle;
		timer = 0f;
		Blocks.SetSolid(shape, true);
		QueueRedraw();
	}

	public override void _PhysicsProcess(double deltaD)
	{
		float delta = (float)deltaD;
		var bodyRect = Player.BodyRect();
		switch (state)
		{
			case State.Idle:
				// Un contact par le dessus ou par le côté suffit
				if (!Player.Dead && Rect.Grow(1.5f).Intersects(bodyRect))
				{
					state = State.Shaking;
					timer = ShakeTime;
				}
				break;
			case State.Shaking:
				timer -= delta;
				if (timer <= 0f)
				{
					state = State.Gone;
					timer = GoneTime;
					Blocks.SetSolid(shape, false);
					EmitSignal(SignalName.Crumbled, this);
				}
				break;
			case State.Gone:
				timer -= delta;
				if (timer <= 0f && !Rect.Intersects(bodyRect.Grow(1f)))
					Reset();
				break;
		}
	}

	public override void _Process(double delta) => QueueRedraw();

	public override void _Draw()
	{
		if (state == State.Gone)
		{
			var c = new Color(0.5f, 0.5f, 0.5f, 0.35f);
			for (float x = Rect.Position.X; x < Rect.End.X; x += 4f)
			{
				DrawRect(new Rect2(x, Rect.Position.Y, 2, 1), c);
				DrawRect(new Rect2(x, Rect.End.Y - 1, 2, 1), c);
			}
			return;
		}
		var off = Vector2.Zero;
		if (state == State.Shaking)
			off = new Vector2((float)GD.RandRange(-1.0, 1.0), (float)GD.RandRange(-1.0, 1.0));
		var r = new Rect2(Rect.Position + off, Rect.Size);
		DrawRect(r, new Color(0.45f, 0.45f, 0.45f));
		DrawRect(new Rect2(r.Position, new Vector2(r.Size.X, 2)), new Color(0.95f, 0.95f, 0.95f));
		// Fissures
		var crack = new Color(0.15f, 0.15f, 0.15f);
		for (float x0 = r.Position.X; x0 < r.End.X; x0 += 16f)
		{
			float top = r.Position.Y;
			DrawLine(new Vector2(x0 + 5, top + 2), new Vector2(x0 + 8, top + 8), crack, 1f);
			DrawLine(new Vector2(x0 + 8, top + 8), new Vector2(x0 + 6, r.End.Y), crack, 1f);
			DrawLine(new Vector2(x0 + 8, top + 8), new Vector2(x0 + 12, top + 11), crack, 1f);
		}
	}
}
