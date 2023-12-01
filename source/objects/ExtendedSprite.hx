package objects;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.animation.FlxAnimation;
import flixel.math.FlxPoint;

/**
	An extended FlxSprite with a bunch of helper functions and other stuff
**/
class ExtendedSprite extends FlxSprite
{
	public var onGraphicLoaded:()->Void = null;
	public var animOffsets:Map<String, FlxPoint> = [];

	public function new(?X:Float = 0, ?Y:Float = 0, ?SimpleGraphic:FlxGraphicAsset, ?Antialiasing:Bool):Void
	{
		super(X, Y, SimpleGraphic is String ? Paths.image(SimpleGraphic) : SimpleGraphic);
		antialiasing = Antialiasing ?? ClientPrefs.data.antialiasing;
	}

	override public function graphicLoaded():Void
	{
		if (onGraphicLoaded != null)
			onGraphicLoaded();
	}

	override public function destroy():Void
	{
		for (anim => offset in animOffsets)
			offset.put();

		animOffsets.clear();
		super.destroy();
	}

	public function playAnim(Name:String, Forced:Bool = false, ?Reverse:Bool = false, ?StartFrame:Int = 0):Void
	{
		// if there is no animation named "Name" then just skips the whole shit
		if (Name == null || !animation.exists(Name))
		{
			FlxG.log.warn('No animation called "$Name"');
			return;
		}
		animation.play(Name, Forced, Reverse, StartFrame);
		
		if (animOffsets.exists(Name))
			offset.copyFrom(animOffsets.get(Name));
	}

	//quick n' easy animation setup
	inline public function addAnim(Name:String, ?Prefix:String, ?Indices:Array<Int>, FrameRate:Int = 24, Looped:Bool = true, ?FlipX:Bool = false, ?FlipY:Bool = false,
			?LoopPoint:Int = 0):FlxAnimation
	{
		if (Prefix != null)
		{
			if (Indices != null && Indices.length > 0)
				animation.addByIndices(Name, Prefix, Indices, "", FrameRate, Looped, FlipX, FlipY);
			else
				animation.addByPrefix(Name, Prefix, FrameRate, Looped, FlipX, FlipY);
		}
		else if (Indices != null && Indices.length > 0)
			animation.add(Name, Indices, FrameRate, Looped, FlipX, FlipY);

		final addedAnim = animation.getByName(Name);
		if (addedAnim != null)
		{
			addedAnim.loopPoint = LoopPoint; // better than -loop anims lmao
		}
		return addedAnim;
	}

	public function getScaledGraphicMidpoint(?point:FlxPoint):FlxPoint
	{
		if (point == null)
			point = FlxPoint.get();
		return point.set(x + (frameWidth * scale.x) * 0.5, y + (frameHeight * scale.y) * 0.5);
	}

	// kinda like setGraphicSize, but with just scale value
	inline public function setScale(?X:Float, ?Y:Float):FlxPoint
		return (X == null && Y == null ? scale : scale.set(X ?? Y, Y ?? X));

	inline public function addOffset(Name:String, X:Float, Y:Float):FlxPoint
	{
		if (animOffsets.exists(Name))
			return animOffsets.get(Name).set(X, Y);

		final point = FlxPoint.get(X, Y);
		animOffsets.set(Name, point);
		return point;
	}
}
