// Plateforme mobile (élément levels/elements/plateforme.gd) : fait l'aller-retour en ligne droite
// entre ses deux bouts, A et B, avec un arrêt à chaque bout. L'aller et le retour ont chacun leur
// vitesse moyenne et leur accélération ; elle peut attendre que le fantôme monte dessus pour
// partir. Elle tient à jour sa vitesse (Motion), que le fantôme garde en la quittant. Assez rapide
// (Propel), elle lance le fantôme quand elle s'arrête au bout de sa course : il file avec son élan.
using Godot;

namespace Lumignon;

public partial class Mover : AnimatableBody2D
{
	// Mêmes valeurs que les menus de levels/elements/plateforme.gd
	public enum TriggerKind { Always, OnBoard, OnBoardBothEnds }
	public enum EaseKind { Linear, SmoothBoth, SmoothStart, SmoothEnd }

	public Vector2 Size = Vector2.Zero;
	public Vector2 Start = Vector2.Zero;   // bout A (coin haut gauche), en pixels
	public Vector2 Course = Vector2.Zero;  // de A à B, en pixels
	public float Speed = 60f;              // vitesse moyenne de l'aller (A → B), px/s
	public float SpeedBack = 60f;          // vitesse moyenne du retour (B → A), px/s
	public EaseKind EaseOut = EaseKind.Linear;   // accélération de l'aller
	public EaseKind EaseBack = EaseKind.Linear;  // accélération du retour
	public float Pause = 0.4f;             // secondes d'arrêt à chaque bout
	public float StartAt;                  // position de départ : 0 = en A, 1 = en B
	public TriggerKind Trigger = TriggerKind.Always;  // quand elle part
	// Vitesse d'arrivée (px/s) à partir de laquelle elle lance le fantôme en s'arrêtant à un bout ;
	// 0 = jamais
	public float Propel = 150f;
	public Player Player;
	public Vector2 Motion = Vector2.Zero;  // vitesse de la dernière image, px/s

	int leg = 1;   // 1 = aller (A → B), -1 = retour (B → A)
	float t;       // secondes écoulées dans le trajet en cours
	float wait;
	bool hold;     // attend que le fantôme monte dessus

	public override void _Ready()
	{
		SyncToPhysics = true;
		Blocks.Unshaded(this);
		AddChild(new CollisionShape2D
		{
			Shape = new RectangleShape2D { Size = Size },
			Position = Size * 0.5f,
		});
		if (StartAt >= 1f)
		{
			leg = -1;
			Position = Start + Course;
		}
		else
		{
			leg = 1;
			float dur = Duration();
			t = Mathf.Clamp(StartAt, 0f, 1f) * dur;
			Position = dur > 0f ? Start + Course * EaseAt(t / dur, EaseOut) : Start;
		}
		hold = Holds();
	}

	float Duration()
	{
		float v = leg > 0 ? Speed : SpeedBack;
		return Course.Length() / Mathf.Max(v, 1f);
	}

	// Part parcourue (0 → 1) après une part p (0 → 1) du temps du trajet
	static float EaseAt(float p, EaseKind kind) => kind switch
	{
		EaseKind.SmoothBoth => 0.5f - 0.5f * Mathf.Cos(Mathf.Pi * p),
		EaseKind.SmoothStart => 1f - Mathf.Cos(Mathf.Pi * 0.5f * p),
		EaseKind.SmoothEnd => Mathf.Sin(Mathf.Pi * 0.5f * p),
		_ => p,
	};

	// Vitesse en fin de trajet, en part de la vitesse moyenne (dérivée de EaseAt en p = 1) : une
	// arrivée douce s'arrête en douceur et ne lance rien
	static float EndSpeed(EaseKind kind) => kind switch
	{
		EaseKind.SmoothBoth => 0f,
		EaseKind.SmoothStart => Mathf.Pi * 0.5f,
		EaseKind.SmoothEnd => 0f,
		_ => 1f,
	};

	// Attend-elle le fantôme avant le trajet qui vient ?
	bool Holds() => Trigger == TriggerKind.OnBoardBothEnds || (Trigger == TriggerKind.OnBoard && leg > 0);

	bool PlayerOn() => Player != null && Player.FloorBody == this;

	public override void _PhysicsProcess(double deltaD)
	{
		float delta = (float)deltaD;
		var prev = Position;
		Step(delta);
		Motion = delta > 0f ? (Position - prev) / delta : Vector2.Zero;
	}

	void Step(float delta)
	{
		float dur = Duration();
		if (dur <= 0f)
			return;
		if (wait > 0f)
		{
			wait -= delta;
			return;
		}
		if (hold)
		{
			if (!PlayerOn())
				return;
			hold = false;
		}
		t += delta;
		float p = Mathf.Min(t / dur, 1f);
		float f = EaseAt(p, leg > 0 ? EaseOut : EaseBack);
		Position = Start + Course * (leg > 0 ? f : 1f - f);
		if (p >= 1f)
		{
			// Arrêt net au bout : le fantôme posé dessus continue sur sa lancée
			if (Propel > 0f && PlayerOn())
			{
				var ease = leg > 0 ? EaseOut : EaseBack;
				var arrive = Course.Normalized() * (leg > 0 ? Speed : SpeedBack) * EndSpeed(ease) * leg;
				if (arrive.Length() >= Propel)
					Player.Fling(arrive);
			}
			leg = -leg;
			t = 0f;
			wait = Pause;
			hold = Holds();
		}
	}

	public override void _Draw()
	{
		DrawRect(new Rect2(Vector2.Zero, Size), new Color(0.75f, 0.75f, 0.75f));
		DrawRect(new Rect2(new Vector2(2, 3), Size - new Vector2(4, 5)), new Color(0.3f, 0.3f, 0.3f));
		for (float x = 4f; x < Size.X - 2f; x += 8f)
			DrawRect(new Rect2(x, 6, 2, 2), new Color(0.85f, 0.85f, 0.85f));
	}
}
