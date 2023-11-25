package objects;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;

class PopupSprite extends FlxSprite
{
	// internal stuff, for reseting shit
	var _spawnPos:FlxPoint = FlxPoint.get();
	var _velocity:FlxPoint = FlxPoint.get();
	var _acceleration:FlxPoint = FlxPoint.get();

	/**
		Should this object be destroyed after leaving the screen?
	**/
	public var autoDestroy:Bool = false;

	/**
		Global game speed. Can be controlled outside of PlatState.
	**/
	@:isVar public static var globalSpeed(get, set):Float = 1.0;

	public function new(?X:Float = 0, ?Y:Float = 0, ?Graphic:FlxGraphicAsset, ?VelocityX:Float = 0, ?VelocityY:Float = 0,
			?AccelerationX:Float = 0, ?AccelerationY:Float = 0):Void
	{
		super(X, Y, Graphic);
		antialiasing = ClientPrefs.data.antialiasing;
		_spawnPos.set(X, Y);
		setVelocity(VelocityX, VelocityY);
		setAcceleration(AccelerationX, AccelerationY);
	}

	// NOT UPDATE???? HOWWWW😱😱
	override public function draw():Void
	{
		if (alive && !isOnScreen(camera))
		{
			autoDestroy ? destroy() : kill();
			return;
		}

		super.draw();
	}

	override function revive():Void
	{
		super.revive();
		setPosition(_spawnPos.x, _spawnPos.y);
		resetVelocity();
		resetAcceleration();
	}

	override public function destroy():Void
	{
		super.destroy();
		_spawnPos = FlxDestroyUtil.put(_spawnPos);
		_velocity = FlxDestroyUtil.put(_velocity);
		_acceleration = FlxDestroyUtil.put(_acceleration);
	}

	/*
	override public function loadGraphic(graphic:FlxGraphicAsset, animated:Bool = false, frameWidth:Int = 0, frameHeight:Int = 0, unique:Bool = false, ?key:String):PopupSprite
		return cast super.loadGraphic(graphic, animated, frameWidth, frameHeight, unique, key);

	override public function loadGraphicFromSprite(Sprite:FlxSprite):PopupSprite
		return cast super.loadGraphicFromSprite(Sprite);

	override public function loadRotatedFrame(Frame:flixel.graphics.frames.FlxFrame, Rotations:Int = 16, AntiAliasing:Bool = false, AutoBuffer:Bool = false):PopupSprite
		return cast super.loadRotatedFrame(Frame, Rotations, AntiAliasing, AutoBuffer);

	override public function makeGraphic(Width:Int, Height:Int, Color:FlxColor = FlxColor.WHITE, Unique:Bool = false, ?Key:String):PopupSprite
		return cast super.makeGraphic(Width, Height, Color, Unique, Key);

	override public function loadRotatedGraphic(Graphic:FlxGraphicAsset, Rotations:Int = 16, Frame:Int = -1, AntiAliasing:Bool = false, AutoBuffer:Bool = false, ?Key:String):PopupSprite
		return cast super.loadRotatedGraphic(Graphic, Rotations, Frame, AntiAliasing, AutoBuffer, Key);

	override public function setFrames(Frames:flixel.graphics.frames.FlxFramesCollection, saveAnimations:Bool = true):PopupSprite
		return cast super.setFrames(Frames, saveAnimations);
	*/

	inline public function addVelocity(X:Float = 0, Y:Float = 0):FlxPoint
	{
		X *= globalSpeed;
		Y *= globalSpeed;
		_velocity.add(X, Y);
		return velocity.add(X, Y);
	}

	inline public function addAcceleration(X:Float = 0, Y:Float = 0):FlxPoint
	{
		X *= Math.pow(globalSpeed, 2);
		Y *= Math.pow(globalSpeed, 2);
		_acceleration.add(X, Y);
		return acceleration.add(X, Y);
	}

	inline public function setVelocity(X:Float = 0, Y:Float = 0):FlxPoint
		return velocity.copyFrom(_velocity.set(X * globalSpeed, Y * globalSpeed));

	inline public function setAcceleration(X:Float = 0, Y:Float = 0):FlxPoint
		return acceleration.copyFrom(_acceleration.set(X * Math.pow(globalSpeed, 2), Y * Math.pow(globalSpeed, 2)));

	inline public function resetVelocity():FlxPoint
		return velocity.copyFrom(_velocity);

	inline public function resetAcceleration():FlxPoint
		return acceleration.copyFrom(_acceleration);

	@:noCompletion inline static function get_globalSpeed():Float
	{
		if (PlayState.instance != null)
			return PlayState.instance.playbackRate;

		return globalSpeed;
	}
	@:noCompletion inline static function set_globalSpeed(speed:Float):Float
	{
		if (PlayState.instance != null) // won't allow to set variable if camera placed in PlayState
			return PlayState.instance.playbackRate;

		return globalSpeed = speed;
	}
}