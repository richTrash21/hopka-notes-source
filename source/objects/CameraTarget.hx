package objects;

import flixel.util.FlxStringUtil;
import flixel.FlxObject;

/**
	Simple object class for use as camera target.
**/
class CameraTarget extends FlxObject
{
	// where this object was created?
	@:noCompletion var _source:String;

	public function new(?x:Float, ?y:Float, ?pos:haxe.PosInfos)
	{
		super(x, y #if FLX_DEBUG , 1, 1 #end);
		allowCollisions = NONE;
		immovable = true;
		#if !FLX_DEBUG
		visible = false;
		#end
		active = false;
		moves = false;
		_source = pos?.className;
	}

	@:noCompletion override function initVars()
	{
		flixelType = OBJECT;
		pixelPerfectPosition = FlxObject.defaultPixelPerfectPosition;
	}

	override public function update(elapsed:Float)
	{
		#if FLX_DEBUG
		@:access(flixel.FlxBasic.activeCount) flixel.FlxBasic.activeCount++;
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
			LabelValuePair.weak("y", y),
			LabelValuePair.weak("source", _source)
		]);
	}
}