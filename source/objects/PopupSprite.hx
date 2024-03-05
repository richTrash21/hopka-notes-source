package objects;

//import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.helpers.FlxPointRangeBounds;
import flixel.util.helpers.FlxBounds;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;

// stupid alias for popup score numbers
class PopupScore extends PopupSprite {}

class PopupSprite extends ExtendedSprite implements ISortable
{
	/**
		Order of this popup. doesn't do anything by itself, but can be used on groups via sortByOrder().
	**/
	public var order:Int = 0;

	/**
		Should this object be destroyed after leaving the screen?
	**/
	public var autoDestroy:Bool = false;

	/**
		Tracker for fade tween.
	**/
	public var fadeTween:FlxTween;

	// internal stuff, for reseting shit
	var _speed:FlxPointRangeBounds;
	var _angleSpeed:FlxBounds<FlxPoint>;

	public function new(minVelocityX:Float = 0, maxVelocityX:Float = 0, minVelocityY:Float = 0, maxVelocityY:Float = 0, minAccelerationX:Float = 0,
			maxAccelerationX:Float = 0, minAccelerationY:Float = 0, maxAccelerationY:Float = 0):Void
	{
		super();
		antialiasing = ClientPrefs.data.antialiasing;
		_speed = new FlxPointRangeBounds(0);
		_angleSpeed = new FlxBounds<FlxPoint>(FlxPoint.get(), FlxPoint.get());
		setVelocity(minVelocityX, maxVelocityX, minVelocityY, maxVelocityY);
		setAcceleration(minAccelerationX, maxAccelerationX, minAccelerationY, maxAccelerationY);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!isOnScreen(camera))
		{
			finishFade();
			killOrDestroy();
		}
	}

	inline function killOrDestroy():Void
	{
		autoDestroy ? destroy() : kill();
	}

	override public function revive():Void
	{
		resetMovement();
		angle = 0;
		alpha = 1;
		super.revive();
	}

	override public function destroy():Void
	{
		super.destroy();
		//_spawnPos = FlxDestroyUtil.put(_spawnPos);
		_speed = FlxDestroyUtil.destroy(_speed);
		FlxDestroyUtil.putArray([_angleSpeed.min, _angleSpeed.max]);
		_angleSpeed = null;
	}

	public function resetMovement():Void
	{
		resetVelocity();
		resetAcceleration();
		resetAngleVelocity();
		resetAngleAcceleration();
	}

	/*inline*/ public function setVelocity(minVelocityX:Float = 0, maxVelocityX:Float = 0, minVelocityY:Float = 0, maxVelocityY:Float = 0):FlxPoint
	{
		_speed.start.min.set(minVelocityX, minVelocityY);
		_speed.start.max.set(maxVelocityX, maxVelocityY);
		return resetVelocity();
	}

	/*inline*/ public function setAcceleration(minAccelerationX:Float = 0, maxAccelerationX:Float = 0, minAccelerationY:Float = 0, maxAccelerationY:Float = 0):FlxPoint
	{
		_speed.end.min.set(minAccelerationX, minAccelerationY);
		_speed.end.max.set(maxAccelerationX, maxAccelerationY);
		return resetAcceleration();
	}

	/*inline*/ public function setAngleVelocity(min:Float = 0, max:Float = 0):Float
	{
		_angleSpeed.min.set(min, max);
		return resetAngleVelocity();
	}

	/*inline*/ public function setAngleAcceleration(min:Float = 0, max:Float = 0):Float
	{
		_angleSpeed.max.set(min, max);
		return resetAngleAcceleration();
	}

	inline public function resetVelocity():FlxPoint
	{
		return velocity.set(FlxG.random.float(_speed.start.min.x, _speed.start.max.x), FlxG.random.float(_speed.start.min.y, _speed.start.max.y));
	}

	inline public function resetAcceleration():FlxPoint
	{
		return acceleration.set(FlxG.random.float(_speed.end.min.x, _speed.end.max.x), FlxG.random.float(_speed.end.min.y, _speed.end.max.y));
	}

	inline public function resetAngleVelocity():Float
	{
		return angularVelocity = FlxG.random.float(_angleSpeed.min.x, _angleSpeed.min.y);
	}

	inline public function resetAngleAcceleration():Float
	{
		return angularAcceleration = FlxG.random.float(_angleSpeed.max.x, _angleSpeed.max.y);
	}

	/**
		Simple fade out tween that kills/destroys (controlled via `autoDestroy`) this sprite after it's completion.
		@param    Duration - Duration of this tween.
		@param    Delay - Delay of this tween.
		@return   This sprite, for chaining stuff.
	**/
	public function fadeOut(Duration:Float = 1, ?Delay:Float = 0):PopupSprite
	{
		cancelFade();
		fadeTween = FlxTween.num(1, 0, Duration, {startDelay: Delay, onComplete: (_) ->
			{
				killOrDestroy();
				fadeTween = null;
			}},
			set_alpha);

		return this;
	}

	/**
		Helper function to get rid of the tween.
	**/
	inline public function cancelFade():Void
	{
		if (fadeTween != null)
		{
			fadeTween.cancel();
			fadeTween = null;
		}
	}

	@:access(flixel.tweens.FlxTween.finish)
	inline public function finishFade():Void
	{
		if (fadeTween != null)
			fadeTween.finish();
	}
}