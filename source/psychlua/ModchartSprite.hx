package psychlua;

class ModchartSprite extends FlxSprite
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.data.antialiasing;
	}

	public function playAnim(name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
	{
		@:privateAccess // if there is no animation named "name" then just skips the whole shit
		if(name == null || animation._animations.get(name) == null) {
			FlxG.log.warn("No animation called \"" + name + "\"");
			return;
		}
		animation.play(name, forced, reverse, startFrame);
		
		var daOffset = animOffsets.get(name);
		if (animOffsets.exists(name))
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);
	}

	public function addOffset(name:String, x:Float, y:Float)
	{
		animOffsets.set(name, [x, y]);
	}
}
