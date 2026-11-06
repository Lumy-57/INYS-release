// Le fantôme : déplacements serrés façon Celeste.
// Coyote time, buffer de saut, saut variable, apex adouci, wall jump et dash 8 directions.
using Godot;

namespace Lumignon;

public partial class Player : CharacterBody2D
{
	[Signal] public delegate void DiedEventHandler();
	[Signal] public delegate void DashedEventHandler();
	[Signal] public delegate void JumpedEventHandler();
	[Signal] public delegate void LandedEventHandler();
	[Signal] public delegate void BonkedEventHandler();

	public const float RunSpeed = 130f;
	public const float GroundAccel = 1100f;
	public const float GroundDecel = 1400f;
	public const float AirAccel = 800f;
	public const float AirDecel = 600f;
	public const float OverspeedDecel = 300f;
	// Sur le givre, on démarre et on freine beaucoup moins vite : on glisse
	public const float IceAccel = 350f;
	public const float IceDecel = 110f;
	public const float Gravity = 950f;
	public const float ApexGravityMult = 0.5f;
	public const float ApexThreshold = 40f;
	public const float MaxFall = 260f;
	public const float FastFall = 360f;
	public const float JumpVelocity = -330f;
	public const float JumpCut = 0.45f;
	public const float CoyoteTime = 0.1f;
	public const float JumpBuffer = 0.12f;
	public const float WallSlideMax = 70f;
	public const float WallJumpX = 170f;
	public const float WallJumpY = -310f;
	public const float WallJumpLock = 0.13f;
	public const float WallCheck = 3f;
	public const float DashSpeed = 380f;
	public const float DashTime = 0.15f;
	public const float DashFreeze = 0.05f;
	public const float DashEndMult = 0.55f;
	public const int MaxDashes = 1;
	public const float UpdraftSpeed = 170f;
	public const float UpdraftAccel = 1500f;
	// Vent vers le bas, à gauche ou à droite (updraft.gd)
	public const float WindDownSpeed = 300f;
	public const float WindSideSpeed = 110f;
	public const float WindSideAccel = 900f;
	// Zéro gravité (zero_gravity.gd) : la vitesse verticale s'éteint doucement
	public const float ZeroGDrag = 200f;

	// Mode Ascension : pas de dash ni de wall jump, on charge son saut au sol et on ne dirige plus
	// rien en l'air ; un mur renvoie le fantôme au lieu de l'arrêter
	public const float AscentWalk = 60f;
	public const float AscentChargeTime = 0.6f;
	public const float AscentJumpMin = -150f;
	public const float AscentJumpMax = -400f;
	public const float AscentJumpX = 120f;
	public const float AscentMaxFall = 400f;
	public const float AscentBounce = 0.55f;

	// Taille de la boîte du fantôme, en pixels
	public static readonly Vector2 BoxSize = new(10, 14);

	static readonly Vector2[] WindDirs = { Vector2.Up, Vector2.Down, Vector2.Left, Vector2.Right };

	public int Facing = 1;
	public int Dashes = MaxDashes;
	public float Coyote;
	public float JumpBufferLeft;
	public float WallLock;
	public float DashTimer;
	public Vector2 DashDir = Vector2.Zero;
	public bool DashPending;
	public float Freeze;
	public bool Jumping;
	public bool WasOnFloor;
	// Vitesse de chute au moment de toucher le sol : dose la poussière d'atterrissage
	public float LandSpeed;
	public bool Dead;
	public bool Mirror;  // reflet du chapitre Miroir : gauche et droite inversées
	public bool Ascent;  // mode Ascension (main.gd)
	public bool Charging;
	public float Charge;  // 0 à 1 pendant qu'on charge le saut
	// Hauteur de la dernière chute, en pixels (du plus haut point du saut jusqu'au sol)
	public float LastDrop;
	float airTop;
	// Plateforme mobile sous le fantôme (Mover.cs), sinon null
	public Mover FloorBody;
	public Vector2 FloorMotion = Vector2.Zero;  // vitesse de cette plateforme, px/s
	// Élan gardé d'une plateforme mobile quittée, jusqu'à toucher le sol ou un mur
	public Vector2 Carry = Vector2.Zero;

	// Dernière image passée dans un courant d'air, par sens : haut, bas, gauche, droite (updraft.gd)
	readonly ulong[] windFrames = new ulong[4];
	readonly float[] windPower = { 1f, 1f, 1f, 1f };  // force de ces courants (1 = normal)
	ulong zeroGFrame;  // posé par les zones de zéro gravité (zero_gravity.gd)
	float zeroGDrag = ZeroGDrag;  // freinage et recharge du dash de la dernière zone traversée
	bool zeroGRefill = true;
	float afterimageTimer;

	public Node2D Visual;
	public PointLight2D Light;
	public CpuParticles2D Trail;

	GDScript ghostVisualScript;
	Node settings;

	public override void _Ready()
	{
		ghostVisualScript = GD.Load<GDScript>("res://scripts/ghost_visual.gd");
		settings = GetNodeOrNull("/root/Settings");
		var glow = GD.Load<GDScript>("res://scripts/glow.gd");

		// Pentes (scripts/slopes.gd) : on y court à vitesse constante et on reste collé en descente ;
		// 45° compte encore comme du sol
		FloorMaxAngle = Mathf.DegToRad(46f);
		FloorConstantSpeed = true;
		FloorSnapLength = 5f;
		// L'élan d'une plateforme mobile est géré à la main (AfterMove) pour qu'il dure tout le saut
		PlatformOnLeave = PlatformOnLeaveEnum.DoNothing;

		var shape = new CollisionShape2D();
		shape.Shape = new RectangleShape2D { Size = BoxSize };
		AddChild(shape);

		Visual = ghostVisualScript.New().As<Node2D>();
		Visual.Position = new Vector2(0, -1);
		AddChild(Visual);

		Light = new PointLight2D
		{
			Texture = glow.Call("make_light_texture").As<Texture2D>(),
			TextureScale = 2f,
			Energy = 1.6f,
			ShadowEnabled = true,
			ShadowFilter = Light2D.ShadowFilterEnum.Pcf5,
			ShadowFilterSmooth = 1.5f,
		};
		AddChild(Light);

		Trail = new CpuParticles2D
		{
			Amount = 16,
			Lifetime = 0.6,
			LocalCoords = false,
			EmissionShape = CpuParticles2D.EmissionShapeEnum.Rectangle,
			EmissionRectExtents = new Vector2(5, 2),
			Position = new Vector2(0, 6),
			Direction = new Vector2(0, -1),
			Spread = 30,
			Gravity = new Vector2(0, -20),
			InitialVelocityMin = 5,
			InitialVelocityMax = 15,
			ScaleAmountMin = 1,
			ScaleAmountMax = 2,
			ColorRamp = glow.Call("fade_gradient", new Color(1, 1, 1, 0.5f)).As<Gradient>(),
		};
		AddChild(Trail);
	}

	// Boîte du fantôme en coordonnées du monde : les blocs s'en servent pour ne jamais l'écraser
	public Rect2 BodyRect() => new(GlobalPosition - BoxSize * 0.5f, BoxSize);

	public override void _PhysicsProcess(double deltaD)
	{
		float delta = (float)deltaD;
		if (Dead)
			return;
		if (Freeze > 0.001f)
		{
			Freeze -= delta;
			return;
		}

		if (Ascent)
		{
			AscentProcess(delta);
			return;
		}

		float ix = AxisX();
		float iy = Input.GetAxis("up", "down");
		bool onFloor = IsOnFloor();
		bool zeroG = InZeroG();
		Vector2 wind = Wind();

		if (onFloor)
		{
			Coyote = CoyoteTime;
			if (DashTimer <= 0f && OnSolidGround())
				Dashes = MaxDashes;
		}
		else
			Coyote -= delta;
		// Zéro gravité : le dash revient dès qu'il est fini, même en l'air
		if (zeroG && zeroGRefill && DashTimer <= 0f)
			Dashes = MaxDashes;

		if (Input.IsActionJustPressed("jump"))
			JumpBufferLeft = JumpBuffer;
		else
			JumpBufferLeft -= delta;
		WallLock -= delta;

		if (Input.IsActionJustPressed("dash") && Dashes > 0 && DashTimer <= 0f)
		{
			StartDash(ix, iy);
			return;
		}

		if (DashTimer > 0f)
		{
			UpdateDash(delta, onFloor);
			return;
		}

		Vector2 v = Velocity;
		// Course horizontale
		if (WallLock <= 0f)
		{
			float accel;
			bool onIce = onFloor && OnIce();
			if (onIce)
				accel = ix != 0f ? IceAccel : IceDecel;
			else if (onFloor)
				accel = ix != 0f ? GroundAccel : GroundDecel;
			else
				accel = ix != 0f ? AirAccel : AirDecel;
			// Vent de côté : la vitesse visée glisse dans son sens (on avance à peine contre lui)
			float target = ix * RunSpeed + wind.X * WindSideSpeed;
			// En l'air, l'élan d'une plateforme quittée s'ajoute : on file avec elle sans pousser
			if (!onFloor)
				target += Carry.X;
			if (wind.X != 0f && ix == 0f)
				accel = WindSideAccel;
			// On garde l'élan d'un dash si on pousse dans le même sens
			if (target != 0f && Mathf.Abs(v.X) > Mathf.Abs(target) && Mathf.Sign(v.X) == Mathf.Sign(target))
				accel = onIce ? IceDecel : OverspeedDecel;
			v.X = Mathf.MoveToward(v.X, target, accel * delta);
		}
		if (ix != 0f)
			Facing = Mathf.Sign(ix);

		int wallDir = onFloor ? 0 : WallDir();

		// Gravité, avec un apex plus doux quand on maintient saut
		float g = Gravity;
		if (Mathf.Abs(v.Y) < ApexThreshold && Input.IsActionPressed("jump"))
			g *= ApexGravityMult;
		float maxFall = iy > 0f ? FastFall : MaxFall;
		if (wallDir != 0 && Mathf.Sign(ix) == wallDir && v.Y > 0f)
			maxFall = WallSlideMax;
		if (wind.Y < 0f)
		{
			// Courant d'air : on monte, sans couper le saut
			v.Y = Mathf.MoveToward(v.Y, UpdraftSpeed * wind.Y, UpdraftAccel * delta);
			Jumping = false;
		}
		else if (wind.Y > 0f)
		{
			// Vent vers le bas : il plaque le fantôme, plus vite qu'une chute
			v.Y = Mathf.MoveToward(v.Y, WindDownSpeed * wind.Y, UpdraftAccel * delta);
			Jumping = false;
		}
		else if (zeroG)
			// Zéro gravité : on flotte sur son élan, qui s'éteint doucement
			v.Y = Mathf.MoveToward(v.Y, 0f, zeroGDrag * delta);
		else
			v.Y = Mathf.MoveToward(v.Y, maxFall, g * delta);

		// Saut variable : relâcher coupe la montée
		if (Jumping && v.Y < 0f && !Input.IsActionPressed("jump"))
		{
			v.Y *= JumpCut;
			Jumping = false;
		}
		if (v.Y >= 0f)
			Jumping = false;
		Velocity = v;

		if (JumpBufferLeft > 0f)
		{
			if (Coyote > 0f)
				Jump();
			else if (wallDir != 0)
				WallJump(wallDir);
		}

		float fall = Velocity.Y;
		MoveAndSlide();
		AfterMove(fall);
	}

	// Mode Ascension. Au sol : on marche lentement, ou on maintient saut pour charger (le fantôme se
	// tasse) ; au relâcher, ou à pleine charge, il part dans la direction tenue à ce moment-là, plus
	// haut selon la charge. En l'air, plus aucun contrôle. Toucher un mur renvoie dans l'autre sens.
	void AscentProcess(float delta)
	{
		float ix = AxisX();
		bool onFloor = IsOnFloor();
		Vector2 v = Velocity;
		if (onFloor)
		{
			Dashes = MaxDashes;
			if (!Charging && Input.IsActionJustPressed("jump"))
			{
				Charging = true;
				Charge = 0f;
			}
			if (Charging)
			{
				Charge = Mathf.Min(1f, Charge + delta / AscentChargeTime);
				v.X = 0f;
				if (ix != 0f)
					Facing = Mathf.Sign(ix);
				Visual.Scale = new Vector2(1f + 0.3f * Charge, 1f - 0.35f * Charge);
				if (!Input.IsActionPressed("jump") || Charge >= 1f)
				{
					Charging = false;
					v = new Vector2(Mathf.Sign(ix) * AscentJumpX, Mathf.Lerp(AscentJumpMin, AscentJumpMax, Charge));
					Charge = 0f;
					Carry = Vector2.Zero;
					Visual.Scale = new Vector2(0.7f, 1.35f);
					EmitSignal(SignalName.Jumped);
				}
			}
			else
			{
				float accel = OnIce() ? (ix != 0f ? IceAccel : IceDecel) : GroundDecel;
				v.X = Mathf.MoveToward(v.X, ix * AscentWalk, accel * delta);
				if (ix != 0f)
					Facing = Mathf.Sign(ix);
			}
		}
		else
			Charging = false;
		v.Y = Mathf.MoveToward(v.Y, AscentMaxFall, Gravity * delta);
		Velocity = v;

		float fall = Velocity.Y;
		float pushX = Velocity.X;
		MoveAndSlide();
		// Rebond : le mur renvoie le fantôme, avec un peu moins d'élan
		if (!IsOnFloor() && pushX != 0f)
		{
			for (int i = 0; i < GetSlideCollisionCount(); i++)
			{
				var n = GetSlideCollision(i).GetNormal();
				if (Mathf.Abs(n.X) > 0.9f && Mathf.Sign(n.X) != Mathf.Sign(pushX))
				{
					Velocity = new Vector2(-pushX * AscentBounce, Velocity.Y);
					Facing = pushX > 0f ? -1 : 1;
					Visual.Scale = new Vector2(0.75f, 1.25f);
					EmitSignal(SignalName.Bonked);
					break;
				}
			}
		}
		if (IsOnFloor() && !WasOnFloor)
		{
			LastDrop = GlobalPosition.Y - airTop;
			Velocity = new Vector2(OnIce() ? Velocity.X : 0f, Velocity.Y);
		}
		airTop = IsOnFloor() ? GlobalPosition.Y : Mathf.Min(airTop, GlobalPosition.Y);
		AfterMove(fall);
	}

	// Appelé par un courant d'air (updraft.gd) à chaque image où le fantôme est dedans
	public void FeelWind(int dir, float force)
	{
		windFrames[dir] = Engine.GetPhysicsFrames();
		windPower[dir] = force;
	}

	// Appelé par une zone de zéro gravité (zero_gravity.gd) à chaque image où le fantôme est dedans
	public void FeelZeroGravity(float drag, bool refill)
	{
		zeroGFrame = Engine.GetPhysicsFrames();
		zeroGDrag = drag;
		zeroGRefill = refill;
	}

	static bool Recent(ulong frame) => frame > 0 && Engine.GetPhysicsFrames() - frame <= 1;

	// Somme des courants d'air où se trouve le fantôme, selon leur force (haut et bas s'annulent,
	// comme gauche et droite)
	Vector2 Wind()
	{
		var w = Vector2.Zero;
		for (int i = 0; i < 4; i++)
			if (Recent(windFrames[i]))
				w += WindDirs[i] * windPower[i];
		return w;
	}

	bool InZeroG() => Recent(zeroGFrame);

	float AxisX()
	{
		float x = Input.GetAxis("left", "right");
		return Mirror ? -x : x;
	}

	void UpdateDash(float delta, bool onFloor)
	{
		// Comme dans Celeste, la direction est lue à la fin du gel : on peut la corriger au dernier moment
		if (DashPending)
		{
			DashPending = false;
			var dir = new Vector2(AxisX(), Input.GetAxis("up", "down"));
			if (dir != Vector2.Zero)
				DashDir = dir.Normalized();
		}
		DashTimer -= delta;
		Velocity = DashDir * DashSpeed;
		afterimageTimer -= delta;
		if (afterimageTimer <= 0f)
		{
			afterimageTimer = 0.03f;
			SpawnAfterimage();
		}
		// Sauter pendant un dash au sol garde la vitesse (petit "hyper")
		if (JumpBufferLeft > 0f && onFloor)
		{
			DashTimer = 0f;
			Jump();
		}
		else if (DashTimer <= 0f)
			Velocity *= DashEndMult;
		float fall = Velocity.Y;
		MoveAndSlide();
		AfterMove(fall);
	}

	void StartDash(float ix, float iy)
	{
		Carry = Vector2.Zero;
		var dir = new Vector2(ix, iy);
		if (dir == Vector2.Zero)
			dir = new Vector2(Facing, 0);
		DashDir = dir.Normalized();
		DashPending = true;
		Dashes -= 1;
		DashTimer = DashTime;
		Freeze = DashFreeze;
		Velocity = Vector2.Zero;
		Jumping = false;
		afterimageTimer = 0f;
		Visual.Scale = Mathf.Abs(DashDir.X) > Mathf.Abs(DashDir.Y) ? new Vector2(1.3f, 0.75f) : new Vector2(0.75f, 1.3f);
		EmitSignal(SignalName.Dashed);
	}

	void Jump()
	{
		Velocity = new Vector2(Velocity.X, JumpVelocity);
		JumpBufferLeft = 0f;
		Coyote = 0f;
		Jumping = true;
		Visual.Scale = new Vector2(0.7f, 1.35f);
		EmitSignal(SignalName.Jumped);
	}

	void WallJump(int wallDir)
	{
		Carry = Vector2.Zero;
		Velocity = new Vector2(-wallDir * WallJumpX, WallJumpY);
		WallLock = WallJumpLock;
		Facing = -wallDir;
		JumpBufferLeft = 0f;
		Jumping = true;
		Visual.Scale = new Vector2(0.7f, 1.35f);
		EmitSignal(SignalName.Jumped);
	}

	// Seule une paroi verticale compte comme mur : une pente ne se grimpe pas en wall jump
	int WallDir()
	{
		foreach (int d in new[] { 1, -1 })
		{
			var hit = MoveAndCollide(new Vector2(WallCheck * d, 0), testOnly: true);
			if (hit != null && Mathf.Abs(hit.GetNormal().X) > 0.9f)
				return d;
		}
		return 0;
	}

	// Le fantôme brille tant que son dash est disponible (blocs de lumière et d'ombre)
	public bool Glowing() => Dead || Dashes > 0;

	// Rend le dash (cristaux, option dash infini) ; vrai s'il manquait
	public bool RefillDash()
	{
		if (Dashes >= MaxDashes)
			return false;
		Dashes = MaxDashes;
		return true;
	}

	// Vrai si au moins une partie du sol touché n'est pas un bloc d'ombre :
	// l'ombre porte le fantôme mais ne recharge pas son dash.
	bool OnSolidGround()
	{
		for (int i = 0; i < GetSlideCollisionCount(); i++)
		{
			var c = GetSlideCollision(i);
			if (c.GetNormal().Y < -0.7f && c.GetCollider() is Node other && !other.IsInGroup("shadow"))
				return true;
		}
		return false;
	}

	// Vrai si le fantôme se tient sur du givre (corps du groupe « ice », main.gd)
	bool OnIce()
	{
		for (int i = 0; i < GetSlideCollisionCount(); i++)
		{
			var c = GetSlideCollision(i);
			if (c.GetNormal().Y < -0.7f && c.GetCollider() is Node other && other.IsInGroup("ice"))
				return true;
		}
		return false;
	}

	void AfterMove(float fall)
	{
		bool onFloor = IsOnFloor();
		// Plateforme mobile : sur elle, on retient sa vitesse ; en la quittant (saut, chute), on la
		// garde. Vers le haut, elle s'ajoute aussi au saut.
		Mover body = null;
		if (onFloor)
		{
			for (int i = 0; i < GetSlideCollisionCount(); i++)
			{
				var c = GetSlideCollision(i);
				if (c.GetNormal().Y < -0.7f && c.GetCollider() is Mover m)
				{
					body = m;
					break;
				}
			}
		}
		if (FloorBody != null && body == null && !onFloor)
		{
			Carry = new Vector2(FloorMotion.X, 0f);
			var v = Velocity;
			v.X += FloorMotion.X;
			if (FloorMotion.Y < 0f)
				v.Y += FloorMotion.Y;
			Velocity = v;
		}
		FloorBody = body;
		FloorMotion = body?.Motion ?? Vector2.Zero;
		if (onFloor || IsOnWall())
			Carry = Vector2.Zero;
		if (onFloor && !WasOnFloor)
		{
			LandSpeed = fall;
			Visual.Scale = new Vector2(1.35f, 0.7f);
			EmitSignal(SignalName.Landed);
		}
		WasOnFloor = onFloor;
	}

	void SpawnAfterimage()
	{
		var ghost = ghostVisualScript.New().As<Node2D>();
		ghost.Set("animated", false);
		ghost.Set("facing", Facing);
		ghost.Set("tint", new Color(1, 1, 1, 0.5f));
		ghost.Scale = Visual.Scale;
		GetParent().AddChild(ghost);
		ghost.GlobalPosition = Visual.GlobalPosition;
		var tw = ghost.CreateTween();
		tw.TweenProperty(ghost, "modulate:a", 0.0, 0.25);
		tw.TweenCallback(Callable.From(ghost.QueueFree));
	}

	public override void _Process(double deltaD)
	{
		float delta = (float)deltaD;
		Visual.Scale = Visual.Scale.Lerp(Vector2.One, 1f - Mathf.Exp(-14f * delta));
		// Sur une pente, la boîte du fantôme ne touche que par un coin : on descend le dessin
		// d'autant pour qu'il pose bien sur le biais
		float sink = 0f;
		if (IsOnFloor() && !Dead)
		{
			var n = GetFloorNormal();
			if (Mathf.Abs(n.Y) > 0.1f)
				sink = 5f * Mathf.Abs(n.X / n.Y);
		}
		var pos = Visual.Position;
		pos.Y = Mathf.Lerp(pos.Y, -1f + sink, 1f - Mathf.Exp(-25f * delta));
		Visual.Position = pos;
		Visual.Set("facing", Facing);
		Visual.Set("gaze", Velocity / 180f);
		float idle = Visual.Get("idle").AsSingle();
		Visual.Set("idle", Velocity.Length() < 1f && !Dead ? idle + delta : 0f);
		// Le fantôme pâlit quand son dash est épuisé : la lumière en dit autant
		bool hasDash = Dashes > 0 || DashTimer > 0f;
		float targetEnergy = hasDash ? 1.6f : 0.8f;
		Light.Energy = Mathf.Lerp(Light.Energy, targetEnergy, 1f - Mathf.Exp(-10f * delta));
		Visual.Set("tint", hasDash ? Colors.White : new Color(0.55f, 0.55f, 0.55f));
	}

	public void Die()
	{
		if (Dead || (settings != null && settings.Get("invincible").AsBool()))
			return;
		Dead = true;
		Carry = Vector2.Zero;
		FloorBody = null;
		Velocity = Vector2.Zero;
		Visual.Visible = false;
		Light.Visible = false;
		Trail.Emitting = false;
		EmitSignal(SignalName.Died);
	}

	// Propulsion par un ressort : rend le dash et annule le dash en cours
	public void Launch(Vector2 v)
	{
		Carry = Vector2.Zero;
		FloorBody = null;
		Velocity = v;
		Dashes = MaxDashes;
		DashTimer = 0f;
		Freeze = 0f;
		Coyote = 0f;
		JumpBufferLeft = 0f;
		Jumping = false;
		Visual.Scale = new Vector2(0.65f, 1.4f);
	}

	public void Respawn(Vector2 pos)
	{
		Carry = Vector2.Zero;
		FloorBody = null;
		GlobalPosition = pos;
		Velocity = Vector2.Zero;
		Dead = false;
		Dashes = MaxDashes;
		DashTimer = 0f;
		Freeze = 0f;
		JumpBufferLeft = 0f;
		Coyote = 0f;
		WallLock = 0f;
		Jumping = false;
		Charging = false;
		Charge = 0f;
		LastDrop = 0f;
		airTop = pos.Y;
		Visual.Visible = true;
		Visual.Scale = new Vector2(0.6f, 1.4f);
		Light.Visible = true;
		Trail.Emitting = true;
	}
}
