package objects;

class GameCamera extends FlxCamera
{
	/**
		Default lerpin' zoom. Not to be confused with `FlxCamera.defaultZoom`!
	**/
	public var targetZoom:Float = 1.0;

	/**
		Should current zoom lerp to the default value?
	**/
	public var updateZoom:Bool;

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
	public var updateLerp(default, set):Bool;

	// internal values
	@:allow(substates.GameOverSubstate)
	var _speed:Float = 2.4;
	var _zoomSpeed:Float = 3.2;

	public function new(?Zoom:Float = 0.0, ?BGAlpha:Float = 1.0, UpdateLerp:Bool = false, UpdateZoom:Bool = false):Void
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

	@:access(flixel.tweens.FlxTweenManager)
	private inline function get_tweeningZoom():Bool // it hurts my eyes but i hope it will do the trick
	{
		var ret:Bool = false;
		FlxTween.globalManager.forEachTweensOf(this, ['zoom'], function(twn:FlxTween) 
		{
			ret = true;
			return;
		});
		return ret;
	}

	override public function update(elapsed:Float):Void
	{
		if (!active) return;

		if (target != null && updateLerp)
			followLerp = elapsed * _speed * cameraSpeed * (FlxG.updateFramerate / 60);

		if (updateZoom && !tweeningZoom)
			zoom = FlxMath.lerp(targetZoom, zoom, Math.max(1 - (elapsed * _zoomSpeed * zoomDecay), 0));

		super.update(elapsed);
	}

	@:noCompletion inline override function set_active(bool:Bool):Bool
	{
		if (!bool) followLerp = 0;
		return active = bool;
	}

	@:noCompletion inline function set_updateLerp(bool:Bool):Bool
	{
		if (!bool) followLerp = 0;
		return updateLerp = bool;
	}
}