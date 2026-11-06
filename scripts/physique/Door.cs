// Porte : un bloc plein qu'une clé de même numéro ouvre (key.gd). Ouverte, elle s'efface et
// le reste jusqu'à la fin du niveau.
using Godot;

namespace Lumignon;

public partial class Door : StaticBody2D
{
	public Rect2 Rect;  // en pixels, coordonnées du niveau
	public int Link = 1;
	public bool Opened;

	CollisionShape2D shape;

	public override void _Ready()
	{
		shape = new CollisionShape2D
		{
			Shape = new RectangleShape2D { Size = Rect.Size },
			Position = Rect.GetCenter(),
		};
		AddChild(shape);
		Blocks.Unshaded(this);
	}

	// Vrai si le fantôme est collé à la porte (posé dessus, contre elle ou dessous)
	public bool Touches(Rect2 body) => !Opened && Rect.Grow(3f).Intersects(body);

	public void Open()
	{
		if (Opened)
			return;
		Opened = true;
		Blocks.SetSolid(shape, false);
		var tw = CreateTween();
		tw.TweenProperty(this, "modulate:a", 0.0, 0.35);
	}

	public override void _Draw()
	{
		DrawRect(Rect, new Color(0.3f, 0.3f, 0.3f));
		DrawRect(Rect.Grow(-0.5f), new Color(0.9f, 0.9f, 0.9f), false, 1f);
		// Planches, et la serrure au milieu
		var line = new Color(0.2f, 0.2f, 0.2f);
		for (float x = Rect.Position.X + 4f; x < Rect.End.X - 2f; x += 4f)
			DrawLine(new Vector2(x, Rect.Position.Y + 2f), new Vector2(x, Rect.End.Y - 2f), line, 1f);
		var c = Rect.GetCenter();
		DrawRect(new Rect2(c.X - 3f, c.Y - 4f, 6f, 8f), new Color(0.85f, 0.85f, 0.85f));
		var hole = new Color(0.05f, 0.05f, 0.05f);
		DrawCircle(c + new Vector2(0f, -1.5f), 1.5f, hole);
		DrawRect(new Rect2(c.X - 0.5f, c.Y - 1f, 1f, 3.5f), hole);
		// Le numéro, en petits points au-dessus de la serrure
		for (int i = 0; i < Link; i++)
			DrawRect(new Rect2(c.X - Link * 1.5f + i * 3f + 0.5f, c.Y - 7f, 2f, 2f), Colors.White);
	}
}
