package psychlua;

class DebugLuaText extends FlxText
{
	inline static final __lifespan = 6.;
	var disableTime = __lifespan;

	public function new()
	{
		super(10, 10, FlxG.width - 20, "", 16);
		setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 1).font = Paths.font("vcr.ttf");
	}

	override function update(elapsed:Float)
	{
		if ((disableTime -= elapsed) < 1)
			alpha = disableTime;
		super.update(elapsed);
		if (alpha == 0 || !isOnScreen(camera))
			kill();
	}

	override function revive()
	{
		super.revive();
		disableTime = __lifespan;
		alpha = 1;
	}
}