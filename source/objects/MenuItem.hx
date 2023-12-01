package objects;

class MenuItem extends FlxSprite
{
	public var targetY:Float = 0;
	public var flashingInt:Int = 0;

	public function new(x:Float, y:Float, weekName:String = '')
	{
		super(x, y, Paths.image('storymenu/$weekName'));
		antialiasing = ClientPrefs.data.antialiasing;
	}

	private var isFlashing:Bool = false;

	public function startFlashing() isFlashing = true;

	// if it runs at 60fps, fake framerate will be 6
	// if it runs at 144 fps, fake framerate will be like 14, and will update the graphic every 0.016666 * 3 seconds still???
	// so it runs basically every so many seconds, not dependant on framerate??
	// I'm still learning how math works thanks whoever is reading this lol
	final fakeFramerate:Int = Math.round((1 / FlxG.elapsed) * 0.1);

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		y = FlxMath.lerp(y, (targetY * 120) + 480, Math.max(elapsed * 10.2, 0));

		if (isFlashing) flashingInt++;
		color = (flashingInt % fakeFramerate >= Math.floor(fakeFramerate * 0.5)) ? 0xFF33ffff : FlxColor.WHITE;
	}
}
