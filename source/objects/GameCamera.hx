package objects;

#if (flixel < "6.0.0")
import flixel.math.FlxRect;
import flixel.FlxObject;
#end

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
	// public var cameraSpeed:Float = 1.0;

	/**
		Should camera lerp be abjusted via `update()`.
	**/
	// public var updateLerp(default, set):Bool;

	/**
		Awfull for optimisation, better for the eyes.
	**/
	public var tweeningZoom(default, null):Bool;

	/**
		Okay, this should help optimize it a bit ig.
	**/
	public var checkForTweens(default, set):Bool = false;
	@:noCompletion var __tweenTimer = 0.; // okay i actually optimized it???? (kinda)

	// internal values
	// @:allow(substates.GameOverSubstate)
	// @:noCompletion var _speed = 2.4;
	@:noCompletion var _zoomSpeed = 3.2;

	public function new(zoom = 0., bgAlpha = 1., /*updateLerp = false,*/ updateZoom = false):Void
	{
		super(0, 0, 0, 0, zoom);
		bgColor.alphaFloat = bgAlpha;
		// this.updateLerp = updateLerp;
		this.updateZoom = updateZoom;
		#if (flixel < "6.0.0")
		followLerp = 1.0;
		#end
	}

	@:access(flixel.tweens.FlxTweenManager.forEachTweensOf)
	override public function update(elapsed:Float):Void
	{
		if (checkForTweens)
		{
			// once per half of current framerate (hope it won't backfire tho)
			final delay = 1 / (Main.fpsVar.currentFPS * .5);
			if ((__tweenTimer += elapsed) > delay)
			{
				__tweenTimer -= delay;
				tweeningZoom = false;
				FlxTween.globalManager.forEachTweensOf(this, ["zoom"], (_) -> tweeningZoom = true);
			}
		}

		// if (target != null && updateLerp)
		//	followLerp = elapsed * _speed * cameraSpeed * (FlxG.updateFramerate * .016666666666666666); // / 60

		if (updateZoom && !tweeningZoom)
			zoom = FlxMath.lerp(targetZoom, zoom, Math.exp(-elapsed * _zoomSpeed * zoomDecay));

		// implementing flixel's 6.0.0 camera changes early
		#if (flixel < "6.0.0")
		// follow the target, if there is one
		if (target != null)
		{
			updateFollow();
			_updateLerp(elapsed);
		}

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);

		flashSprite.filters = filtersEnabled ? filters : null;

		updateFlashSpritePosition();
		updateShake(elapsed);
		#else
		super.update();
		#end
	}

	@:noCompletion function set_checkForTweens(bool:Bool):Bool
	{
		if (!bool)
			tweeningZoom = false;

		return checkForTweens = bool;
	}

	/*@:noCompletion override function set_active(bool:Bool):Bool
	{
		if (!bool)
			tweeningZoom = false;

		return active = bool;
	}*/

	/*@:noCompletion function set_updateLerp(bool:Bool):Bool
	{
		if (!bool)
		{
			followLerp = 0;
			tweeningZoom = false;
		}
		return updateLerp = bool;
	}*/

	// 6.0.0 camera changes
	#if (flixel < "6.0.0")
	override function updateFollow()
	{
		// Either follow the object closely,
		// or double check our deadzone and update accordingly.
		if (deadzone == null)
		{
			target.getMidpoint(_point);
			_point.addPoint(targetOffset);
			_scrollTarget.set(_point.x - width * 0.5, _point.y - height * 0.5);
		}
		else
		{
			var edge:Float;
			var targetX:Float = target.x + targetOffset.x;
			var targetY:Float = target.y + targetOffset.y;

			if (style == SCREEN_BY_SCREEN)
			{
				if (targetX >= viewRight)
				{
					_scrollTarget.x += viewWidth;
				}
				else if (targetX + target.width < viewLeft)
				{
					_scrollTarget.x -= viewWidth;
				}

				if (targetY >= viewBottom)
				{
					_scrollTarget.y += viewHeight;
				}
				else if (targetY + target.height < viewTop)
				{
					_scrollTarget.y -= viewHeight;
				}
				
				// without this we see weird behavior when switching to SCREEN_BY_SCREEN at arbitrary scroll positions
				bindScrollPos(_scrollTarget);
			}
			else
			{
				edge = targetX - deadzone.x;
				if (_scrollTarget.x > edge)
				{
					_scrollTarget.x = edge;
				}
				edge = targetX + target.width - deadzone.x - deadzone.width;
				if (_scrollTarget.x < edge)
				{
					_scrollTarget.x = edge;
				}

				edge = targetY - deadzone.y;
				if (_scrollTarget.y > edge)
				{
					_scrollTarget.y = edge;
				}
				edge = targetY + target.height - deadzone.y - deadzone.height;
				if (_scrollTarget.y < edge)
				{
					_scrollTarget.y = edge;
				}
			}

			if ((target is FlxSprite))
			{
				if (_lastTargetPosition == null)
				{
					_lastTargetPosition = FlxPoint.get(target.x, target.y); // Creates this point.
				}
				_scrollTarget.x += (target.x - _lastTargetPosition.x) * followLead.x;
				_scrollTarget.y += (target.y - _lastTargetPosition.y) * followLead.y;

				_lastTargetPosition.x = target.x;
				_lastTargetPosition.y = target.y;
			}
		}
	}

	function _updateLerp(elapsed:Float)
	{
		final boundLerp = FlxMath.bound(followLerp, 0, 1);
		// Adjust lerp based on the current frame rate so lerp is less framerate dependant
		final adjustedLerp = 1.0 - Math.pow(1.0 - boundLerp, elapsed * 60);
		if (adjustedLerp >= 1)
		{
			scroll.copyFrom(_scrollTarget); // no easing
		}
		else
		{
			scroll.x += (_scrollTarget.x - scroll.x) * adjustedLerp;
			scroll.y += (_scrollTarget.y - scroll.y) * adjustedLerp;
		}
	}
	
	/**
	 * Tells this camera object what `FlxObject` to track.
	 *
	 * @param   target   The object you want the camera to track. Set to `null` to not follow anything.
	 * @param   style    Leverage one of the existing "deadzone" presets. Default is `LOCKON`.
	 *                   If you use a custom deadzone, ignore this parameter and
	 *                   manually specify the deadzone after calling `follow()`.
	 * @param   lerp     How much lag the camera should have (can help smooth out the camera movement).
	 */
	override public function follow(target:FlxObject, ?style:FlxCameraFollowStyle, ?lerp:Float):Void
	{
		this.style = style ?? LOCKON;
		this.target = target;
		followLerp = lerp ?? 1.0;
		var helper:Float;
		_lastTargetPosition = null;

		switch (style)
		{
			case LOCKON:
				var w = 0.0;
				var h = 0.0;
				if (target != null)
				{
					w = target.width;
					h = target.height;
				}
				deadzone = FlxRect.get((width - w) * 0.5, (height - h) * 0.5 - h * 0.25, w, h);

			case PLATFORMER:
				final w = (width * 0.125); // / 8
				final h = (height * 0.3333333333333333); // / 3
				deadzone = FlxRect.get((width - w) * 0.5, (height - h) * 0.5 - h * 0.25, w, h);

			case TOPDOWN:
				helper = Math.max(width, height) * 0.25;
				deadzone = FlxRect.get((width - helper) * 0.5, (height - helper) * 0.5, helper, helper);

			case TOPDOWN_TIGHT:
				helper = Math.max(width, height) * 0.125; // / 8
				deadzone = FlxRect.get((width - helper) * 0.5, (height - helper) * 0.5, helper, helper);

			case SCREEN_BY_SCREEN:
				deadzone = FlxRect.get(0, 0, width, height);

			case NO_DEAD_ZONE:
				deadzone = null;
		}
	}

	@:noCompletion override inline function set_followLerp(value:Float):Float
	{
		return followLerp = value;
	}
	#end
}