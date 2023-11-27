package objects;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;

// stupid alias for popup score numbers
class PopupScore extends PopupSprite {}

class PopupSprite extends FlxSprite
{
	// internal stuff, for reseting shit
	//var _spawnPos:FlxPoint = FlxPoint.get();
	var _velocityX:FlxPoint = FlxPoint.get();
	var _velocityY:FlxPoint = FlxPoint.get();
	var _accelerationX:FlxPoint = FlxPoint.get();
	var _accelerationY:FlxPoint = FlxPoint.get();
	var _angleVelocity:FlxPoint = FlxPoint.get();
	var _angleAcceleration:FlxPoint = FlxPoint.get();

	/**
		Should this object be destroyed after leaving the screen?
	**/
	public var autoDestroy:Bool = false;

	/**
		Global game speed. Can be controlled outside of PlatState.
	**/
	@:isVar public static var globalSpeed(get, set):Float = 1.0;

	public function new(minVelocityX:Float = 0, maxVelocityX:Float = 0, minVelocityY:Float = 0, maxVelocityY:Float = 0, minAccelerationX:Float = 0,
			maxAccelerationX:Float = 0, minAccelerationY:Float = 0, maxAccelerationY:Float = 0):Void
	{
		super();
		antialiasing = ClientPrefs.data.antialiasing;
		setVelocity(minVelocityX, maxVelocityX, minVelocityY, maxVelocityY);
		setAcceleration(minAccelerationX, maxAccelerationX, minAccelerationY, maxAccelerationY);
	}

	// NOT UPDATE???? HOWWWW😱😱
	override public function draw():Void
	{
		super.draw();

		if (alive && !isOnScreen(camera))
		{
			autoDestroy ? destroy() : kill();
			return;
		}
	}

	override public function revive():Void
	{
		//setPosition(_spawnPos.x, _spawnPos.y);
		resetMovement();
		angle = 0;
		super.revive();
	}

	override public function destroy():Void
	{
		super.destroy();
		//_spawnPos = FlxDestroyUtil.put(_spawnPos);
		_velocityX = FlxDestroyUtil.put(_velocityX);
		_velocityY = FlxDestroyUtil.put(_velocityY);
		_accelerationX = FlxDestroyUtil.put(_accelerationX);
		_accelerationY = FlxDestroyUtil.put(_accelerationY);
		_angleVelocity = FlxDestroyUtil.put(_angleVelocity);
		_angleAcceleration = FlxDestroyUtil.put(_angleAcceleration);
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

	public function resetMovement():Void
	{
		resetVelocity();
		resetAcceleration();
		resetAngleVelocity();
		resetAngleAcceleration();
	}

	inline public function setVelocity(minVelocityX:Float = 0, maxVelocityX:Float = 0, minVelocityY:Float = 0, maxVelocityY:Float = 0):FlxPoint
	{
		_velocityX.set(minVelocityX * globalSpeed, maxVelocityX * globalSpeed);
		_velocityY.set(minVelocityY * globalSpeed, maxVelocityY * globalSpeed);
		return resetVelocity();
	}

	inline public function setAcceleration(minAccelerationX:Float = 0, maxAccelerationX:Float = 0, minAccelerationY:Float = 0, maxAccelerationY:Float = 0):FlxPoint
	{
		_accelerationX.set(minAccelerationX * Math.pow(globalSpeed, 2), maxAccelerationX * Math.pow(globalSpeed, 2));
		_accelerationY.set(minAccelerationY * Math.pow(globalSpeed, 2), maxAccelerationY * Math.pow(globalSpeed, 2));
		return resetAcceleration();
	}

	inline public function setAngleVelocity(min:Float = 0, max:Float = 0):Float
	{
		_angleVelocity.set(min * globalSpeed, max * globalSpeed);
		return resetAngleVelocity();
	}

	inline public function setAngleAcceleration(min:Float = 0, max:Float = 0):Float
	{
		_angleAcceleration.set(min * globalSpeed, max * globalSpeed);
		return resetAngleAcceleration();
	}

	inline public function resetVelocity():FlxPoint
		return velocity.set(FlxG.random.float(_velocityX.x, _velocityX.y), FlxG.random.float(_velocityY.x, _velocityY.y));

	inline public function resetAcceleration():FlxPoint
		return acceleration.set(FlxG.random.float(_accelerationX.x, _accelerationX.y), FlxG.random.float(_accelerationY.x, _accelerationY.y));

	inline public function resetAngleVelocity():Float
		return angularVelocity = FlxG.random.float(_angleVelocity.x, _angleVelocity.y);

	inline public function resetAngleAcceleration():Float
		return angularAcceleration = FlxG.random.float(_angleAcceleration.x, _angleAcceleration.y);

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