package objects;

//import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.helpers.FlxPointRangeBounds;
import flixel.util.helpers.FlxBounds;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;

// stupid alias for popup score numbers
class PopupScore extends PopupSprite
{
	public function new(minVelocityX = 0., maxVelocityX = 0., minVelocityY = 0., maxVelocityY = 0., minAccelerationX = 0., maxAccelerationX = 0.,
		minAccelerationY = 0., maxAccelerationY = 0.):Void
	{
		super(minVelocityX, maxVelocityX, minVelocityY, maxVelocityY, minAccelerationX, maxAccelerationX, minAccelerationY, maxAccelerationY);
	}
}

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
		After what time this sprite should fade?
		Do not do anything if set to `null`.
	**/
	public var fadeTime:Null<Float>;

	/**
		At whitch speed this sprite should fade?
	**/
	public var fadeSpeed:Float = 1;

	// internal stuff, for reseting shit
	var _speed:FlxPointRangeBounds;
	var _angleSpeed:FlxBounds<FlxPoint>;
	var _timer = 0.;

	public function new(minVelocityX = 0., maxVelocityX = 0., minVelocityY = 0., maxVelocityY = 0., minAccelerationX = 0., maxAccelerationX = 0.,
			minAccelerationY = 0., maxAccelerationY = 0.):Void
	{
		super();
		_speed = new FlxPointRangeBounds(0.);
		_angleSpeed = new FlxBounds<FlxPoint>(FlxPoint.get(), FlxPoint.get());
		setVelocity(minVelocityX, maxVelocityX, minVelocityY, maxVelocityY);
		setAcceleration(minAccelerationX, maxAccelerationX, minAccelerationY, maxAccelerationY);
	}

	override public function update(elapsed:Float):Void
	{
		if (fadeTime != null)
			if ((_timer += elapsed) >= fadeTime)
				alpha -= elapsed * fadeSpeed;

		super.update(elapsed);

		if (!isOnScreen(camera) || (fadeTime != null && alpha == 0))
		{
			if (autoDestroy)
				destroy();
			else
				kill();
		}
	}

	override public function revive():Void
	{
		resetMovement();
		angle = 0;
		alpha = 1;
		fadeTime = null;
		fadeSpeed = 1;
		_timer = 0;
		super.revive();
	}

	override public function destroy():Void
	{
		_speed = FlxDestroyUtil.destroy(_speed);
		_angleSpeed.min.put();
		_angleSpeed.max.put();
		_angleSpeed = null;
		fadeTime = null;
		super.destroy();
	}

	public function resetMovement():Void
	{
		resetVelocity();
		resetAcceleration();
		resetAngleVelocity();
		resetAngleAcceleration();
	}

	public function setVelocity(minVelocityX:Float = 0, maxVelocityX:Float = 0, minVelocityY:Float = 0, maxVelocityY:Float = 0):FlxPoint
	{
		_speed.start.min.set(minVelocityX, minVelocityY);
		_speed.start.max.set(maxVelocityX, maxVelocityY);
		return resetVelocity();
	}

	public function setAcceleration(minAccelerationX:Float = 0, maxAccelerationX:Float = 0, minAccelerationY:Float = 0, maxAccelerationY:Float = 0):FlxPoint
	{
		_speed.end.min.set(minAccelerationX, minAccelerationY);
		_speed.end.max.set(maxAccelerationX, maxAccelerationY);
		return resetAcceleration();
	}

	public function setAngleVelocity(min:Float = 0, max:Float = 0):Float
	{
		_angleSpeed.min.set(min, max);
		return resetAngleVelocity();
	}

	public function setAngleAcceleration(min:Float = 0, max:Float = 0):Float
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

	// the menacing sounding helper
	@:noCompletion inline function killOrDestroy():Void
	{
		autoDestroy ? destroy() : kill();
	}
}