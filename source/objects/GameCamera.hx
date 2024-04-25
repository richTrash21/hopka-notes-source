package objects;

import flixel.math.FlxRect;

class GameCamera extends FlxCamera
{
	// helper for fixing render on camera with angle applied
	@:noCompletion static final __angleMatrix = new flixel.math.FlxMatrix();
	@:noCompletion static final __rotatedBounds = FlxRect.get();
	@:noCompletion static final __origin = FlxPoint.get();

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
		Awfull for optimisation, better for the eyes.
	**/
	public var tweeningZoom(default, null):Bool;

	/**
		Okay, this should help optimize it a bit ig.
	**/
	public var checkForTweens(default, set):Bool = false;

	/**
		Makes that camera propertly renders this camera when rotated
		TODO: fix fill()
	**/
	public var renderAngle:Bool;

	/**
		Pauses fx and camera movement.
	**/
	public var paused:Bool;

	// okay i actually optimized it???? (kinda)
	@:noCompletion var __tweenTimer = 0.0;
	@:noCompletion var _angleChanged = false;
	@:noCompletion var _sinAngle = 0.0;
	@:noCompletion var _cosAngle = 1.0;

	public function new(zoom = 0.0, bgColor = FlxColor.BLACK, updateZoom = false):Void
	{
		super(0, 0, 0, 0, zoom);
		this.bgColor = bgColor;
		this.updateZoom = updateZoom;
	}

	@:access(flixel.tweens.FlxTweenManager._tweens)
	@:access(flixel.tweens.FlxTweenManager.forEachTweensOf)
	override public function update(elapsed:Float):Void
	{
		updateFlashSpritePosition();

		if (!paused)
		{
			if (checkForTweens)
			{
				// once per half of current framerate (hope it won't backfire tho)
				final delay = 1 / (FlxG.updateFramerate * 0.5);
				if ((__tweenTimer += elapsed) > delay)
				{
					__tweenTimer -= delay;
					tweeningZoom = false;
					// only when necessary
					if (FlxTween.globalManager._tweens.length != 0)
						FlxTween.globalManager.forEachTweensOf(this, ["zoom"], (_) -> tweeningZoom = true);
				}
			}

			if (updateZoom && !tweeningZoom && zoom != targetZoom)
				zoom = CoolUtil.lerpElapsed(zoom, targetZoom, 0.055 * zoomDecay, elapsed);

			// follow the target, if there is one
			if (target != null)
			{
				updateFollow();
				updateLerp(elapsed);
			}

			updateScroll();
			updateFlash(elapsed);
			updateFade(elapsed);
			updateShake(elapsed);
		}

		flashSprite.filters = filtersEnabled ? filters : null;

		if (FlxG.renderTile && renderAngle)
		{
			if (_angleChanged)
			{
				final radians = angle * flixel.math.FlxAngle.TO_RAD;
				_sinAngle = Math.sin(radians);
				_cosAngle = Math.cos(radians);
			}
			__angleMatrix.identity();
			__angleMatrix.translate(-width * 0.5, -height * 0.5);
			__angleMatrix.scale(totalScaleX, totalScaleY);
			__angleMatrix.rotateWithTrig(_cosAngle, _sinAngle);
			__angleMatrix.translate(width * 0.5, height * 0.5);
			__angleMatrix.translate(flashSprite.x - _flashOffset.x, flashSprite.y - _flashOffset.y);
			canvas.transform.matrix = __angleMatrix;
		}
	}

	override public function fill(color:FlxColor, blendAlpha = true, fxAlpha = 1.0, ?graphics:openfl.display.Graphics)
	{
		if (FlxG.renderBlit)
		{
			if (blendAlpha)
			{
				_fill.fillRect(_flashRect, color);
				buffer.copyPixels(_fill, _flashRect, _flashPoint, null, null, blendAlpha);
			}
			else
			{
				buffer.fillRect(_flashRect, color);
			}
		}
		else // TODO? - find a way to optimise rotated fill
		{
			if (fxAlpha == 0)
				return;

			__get__rotated__bounds();
			final targetGraphics = graphics == null ? canvas.graphics : graphics;
			targetGraphics.beginFill(color, fxAlpha);
			// i'm drawing rect with these parameters to avoid light lines at the top and left of the camera,
			// which could appear while cameras fading
			targetGraphics.drawRect(__rotatedBounds.x - 1, __rotatedBounds.y - 1, __rotatedBounds.width + 2, __rotatedBounds.height + 2);
			targetGraphics.endFill();
		}
	}

	override public function containsRect(rect:FlxRect):Bool
	{
		return __get__rotated__bounds().overlaps(rect);
	}

	@:noCompletion extern inline function __get__rotated__bounds():FlxRect
	{
		__rotatedBounds.set(viewMarginLeft, viewMarginTop, viewWidth, viewHeight);
		if (renderAngle)
		{
			__origin.set(__rotatedBounds.width * 0.5, __rotatedBounds.height * 0.5);
			__rotatedBounds.getRotatedBounds(angle, __origin, __rotatedBounds);
		}
		return __rotatedBounds;
	}

	@:noCompletion inline function set_checkForTweens(bool:Bool):Bool
	{
		if (!bool)
			tweeningZoom = false;

		return checkForTweens = bool;
	}

	@:noCompletion override function set_angle(angle:Float):Float
	{
		if (this.angle != angle)
			_angleChanged = true;

		return super.set_angle(angle);
	}
}