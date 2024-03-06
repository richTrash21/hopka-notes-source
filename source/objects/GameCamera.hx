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

	/**
		Awfull for optimisation, better for the eyes.
	**/
	public var tweeningZoom(get, never):Bool;

	// okay i actually optimized it???? (kinda)
	var __prevTweening = false;
	var __updateTimer = true;
	var __tweenTimer = 0.;

	// internal values
	@:allow(substates.GameOverSubstate)
	var _speed:Float = 2.4;
	var _zoomSpeed:Float = 3.2;

	public function new(zoom = 0.0, bgAlpha = 1.0, updateLerp = false, updateZoom = false):Void
	{
		super(0, 0, 0, 0, zoom);
		bgColor.alphaFloat = bgAlpha;
		this.updateLerp = updateLerp;
		this.updateZoom = updateZoom;
	}

	override public function update(elapsed:Float):Void
	{
		if (!active)
			return;

		// update tween timer once per frame
		__updateTimer = true;

		if (target != null && updateLerp)
			followLerp = elapsed * _speed * cameraSpeed * (FlxG.updateFramerate / 60);

		if (updateZoom && !tweeningZoom)
			zoom = FlxMath.lerp(targetZoom, zoom, Math.max(1 - (elapsed * _zoomSpeed * zoomDecay), 0));

		super.update(elapsed);
	}

	@:access(flixel.tweens.FlxTweenManager)
	@:noCompletion /*inline*/ function get_tweeningZoom():Bool // it hurts my eyes but i hope it will do the trick
	{
		// once per half of framerate cap (basically every second frame)
		final delay = 1 / (FlxG.updateFramerate * .5);
		if (__updateTimer && (__tweenTimer += FlxG.elapsed) < delay)
		{
			// pretty smart i think??? maybe i can de better??????
			// nah, will do for now
			__updateTimer = false;
			return __prevTweening;
		}

		__tweenTimer -= delay;
		var ret = false;
		FlxTween.globalManager.forEachTweensOf(this, ["zoom"], (_) -> ret = true);
		return __prevTweening = ret;
	}

	@:noCompletion inline override function set_active(bool:Bool):Bool
	{
		if (!bool)
			followLerp = 0;
		return active = bool;
	}

	@:noCompletion inline function set_updateLerp(bool:Bool):Bool
	{
		if (!bool)
			followLerp = 0;
		return updateLerp = bool;
	}
}