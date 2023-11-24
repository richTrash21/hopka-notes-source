package objects;

class GameCamera extends FlxCamera
{
	/**
		Default lerpin' zoom. Not to be confused with `FlxCamera.defaultZoom`!
	**/
	public var defaultZoom:Float = 1.0;

	/**
		Should current zoom lerp to the default value?
	**/
	public var updateZoom:Bool = false;

	/**
		How fast zoom should lerp?
	**/
	public var zoomDecay:Float = 1.0;

	/**
	 	Self explanatory innit? (БЛЯТЬ НАХУЙ Я ЮЗАЮ БРИТАНСКИЙ СЛЕНГ ХАЗВХАВЗ)
	**/
	public var cameraSpeed:Float = 1.0;

	/**
		Should camera lerp be updated via `update()`.
	**/
	public var updateLerp(default, set):Bool = false;

	/**
		Controlls whenever `update()` should be called.
	**/
	public var paused(default, set):Bool = false;

	/**
		Global game speed. Can be controlled outside of PlatState.
	**/
	@:isVar public static var globalSpeed(get, set):Float = 1.0;

	// internal values
	var _speed:Float = 2.4;
	var _zoomSpeed:Float = 3.125;

	public function new(Zoom:Float = 0.0, BGAlpha:Float = 1.0, UpdateLerp:Bool = false, UpdateZoom:Bool = false)
	{
		super(0, 0, 0, 0, Zoom);
		bgColor.alphaFloat = BGAlpha;
		updateLerp = UpdateLerp;
		updateZoom = UpdateZoom;
	}

	/**
		Awfull for optimisation, better for eyes.
	**/
	public var tweeningZoom(get, never):Bool;

	private function get_tweeningZoom():Bool // it hurts my eyes but i hope it will do the trick
	{
		var ret:Bool = false;
		@:privateAccess
		FlxTween.globalManager.forEachTweensOf(this, ['zoom'], function(twn:FlxTween) 
		{
			ret = true;
			return;
		});
		return ret;
	}

	override public function update(elapsed:Float)
	{
		if (paused) return;

		if (target != null && updateLerp)
			followLerp = elapsed * _speed * cameraSpeed * globalSpeed * (FlxG.updateFramerate / 60);

		if (updateZoom && !tweeningZoom)
			zoom = FlxMath.lerp(defaultZoom, zoom, Math.max(1 - (elapsed * _zoomSpeed * zoomDecay * globalSpeed), 0));

		super.update(elapsed);
	}

	@:noCompletion inline function set_paused(bool:Bool):Bool
	{
		if (bool) followLerp = 0;
		return paused = bool;
	}

	@:noCompletion inline function set_updateLerp(bool:Bool):Bool
	{
		if (!bool) followLerp = 0;
		return updateLerp = bool;
	}

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