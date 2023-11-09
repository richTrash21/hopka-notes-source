package psychlua;

class ModchartSprite extends FlxSprite
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	public function new(?x:Float = 0, ?y:Float = 0, ?simpleGraphic:flixel.system.FlxAssets.FlxGraphicAsset)
	{
		super(x, y, simpleGraphic);
		antialiasing = ClientPrefs.data.antialiasing;
	}

	public function playAnim(name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
	{
		// if there is no animation named "name" then just skips the whole shit
		if(name == null || animation.getByName(name) == null) {
			FlxG.log.warn("No animation called \"" + name + "\"");
			return;
		}
		animation.play(name, forced, reverse, startFrame);
		
		if (animOffsets.exists(name)) {
			var daOffset = animOffsets.get(name);
			offset.set(daOffset[0], daOffset[1]);
		}
	}

	inline public function addOffset(name:String, x:Float, y:Float)
		animOffsets.set(name, [x, y]);
}
