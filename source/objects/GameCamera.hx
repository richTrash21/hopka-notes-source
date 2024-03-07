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
		Should camera lerp be abjusted via `update()`.
	**/
	public var updateLerp(default, set):Bool;

	/**
		Awfull for optimisation, better for the eyes.
	**/
	public var tweeningZoom(default, null):Bool;
	@:noCompletion var __tweenTimer = 0.; // okay i actually optimized it???? (kinda)

	// internal values
	@:allow(substates.GameOverSubstate)
	@:noCompletion var _speed = 2.4;
	@:noCompletion var _zoomSpeed = 3.2;

	public function new(zoom = 0., bgAlpha = 1., updateLerp = false, updateZoom = false):Void
	{
		super(0, 0, 0, 0, zoom);
		bgColor.alphaFloat = bgAlpha;
		this.updateLerp = updateLerp;
		this.updateZoom = updateZoom;
	}

	@:access(flixel.tweens.FlxTweenManager.forEachTweensOf)
	override public function update(elapsed:Float):Void
	{
		if (!active)
			return;

		// once per half of current framerate (hope it won't backfire tho)
		final delay = 1 / (Main.fpsVar.currentFPS * .5);
		if ((__tweenTimer += FlxG.elapsed) > delay)
		{
			__tweenTimer -= delay;
			tweeningZoom = false;
			FlxTween.globalManager.forEachTweensOf(this, ["zoom"], (_) -> tweeningZoom = true);
		}

		if (target != null && updateLerp)
			followLerp = elapsed * _speed * cameraSpeed * (FlxG.updateFramerate / 60);

		if (updateZoom && !tweeningZoom)
			zoom = FlxMath.lerp(targetZoom, zoom, Math.max(1 - (elapsed * _zoomSpeed * zoomDecay), 0));

		super.update(elapsed);
	}

	@:noCompletion /*inline*/ override function set_active(bool:Bool):Bool
	{
		if (!bool)
		{
			followLerp = 0;
			tweeningZoom = false;
		}
		return active = bool;
	}

	@:noCompletion /*inline*/ function set_updateLerp(bool:Bool):Bool
	{
		if (!bool)
		{
			followLerp = 0;
			tweeningZoom = false;
		}
		return updateLerp = bool;
	}
}