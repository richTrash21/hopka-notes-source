package objects;

import flixel.util.FlxStringUtil;
import flixel.FlxObject;

/**
	Simple object class for use as camera target.
**/
class CameraTarget extends FlxObject
{
	public function new(?x:Float, ?y:Float)
	{
		super(x, y, 1, 1);
		allowCollisions = NONE;
		immovable = true;
		visible = false;
		moves = false;
	}

	@:noCompletion override function initVars()
	{
		flixelType = OBJECT;
		pixelPerfectPosition = FlxObject.defaultPixelPerfectPosition;
	}

	@:access(flixel.FlxBasic.activeCount)
	override public function update(elapsed:Float)
	{
		#if FLX_DEBUG
		FlxBasic.activeCount++;
		#end
	}

	override public function reset(x:Float, y:Float)
	{
		setPosition(x, y);
		revive();
	}

	override public function getScreenPosition(?result:FlxPoint, ?camera:FlxCamera):FlxPoint
	{
		if (result == null)
			result = FlxPoint.get();

		if (camera == null)
			camera = FlxG.camera;

		result.set(x, y);
		if (pixelPerfectPosition)
			result.floor();

		return result.subtract(camera.scroll.x, camera.scroll.y);
	}

	override public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("x", x),
			LabelValuePair.weak("y", y)
		]);
	}
}