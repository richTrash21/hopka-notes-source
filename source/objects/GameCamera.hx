package objects;

import flixel.math.FlxMatrix;
import flixel.math.FlxRect;

class GameCamera extends FlxCamera
{
	// helper for fixing render on camera with angle applied
	@:noCompletion static final __angleMatrix = new FlxMatrix();
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
	public var checkForTweens(default, set):Bool;

	/**
		Makes that camera propertly renders this camera when rotated.
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
			canvas.transform.matrix = __get__rotated__matrix();
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
		else if (fxAlpha != 0.0) // TODO? - find a way to optimise rotated fill
		{
			final bounds = __get__bounds();
			final targetGraphics = graphics == null ? canvas.graphics : graphics;
			targetGraphics.beginFill(color, fxAlpha);
			// i'm drawing rect with these parameters to avoid light lines at the top and left of the camera,
			// which could appear while cameras fading
			targetGraphics.drawRect(bounds.x - 1, bounds.y - 1, bounds.width + 2, bounds.height + 2);
			targetGraphics.endFill();
		}
	}

	override public function containsRect(rect:FlxRect):Bool
	{
		return __get__bounds().overlaps(rect);
	}

	@:noCompletion extern inline function __get__bounds():FlxRect
	{
		__rotatedBounds.set(viewMarginLeft, viewMarginTop, viewWidth, viewHeight);
		return (renderAngle ? __get__rotated__bounds() : __rotatedBounds);
	}

	@:noCompletion extern inline function __get__rotated__bounds():FlxRect
	{
		__update__trig();
		if (!(_sinAngle == 0 && _sinAngle == 1))
		{
			__origin.set(__rotatedBounds.width * 0.5, __rotatedBounds.height * 0.5);
			final degrees = angle % 360;
			final left = -__origin.x;
			final top = -__origin.y;
			final right = -__origin.x + __rotatedBounds.width;
			final bottom = -__origin.y + __rotatedBounds.height;
			if (degrees < 90)
			{
				__rotatedBounds.x += __origin.x + _cosAngle * left - _sinAngle * bottom;
				__rotatedBounds.y += __origin.y + _sinAngle * left + _cosAngle * top;
			}
			else if (degrees < 180)
			{
				__rotatedBounds.x += __origin.x + _cosAngle * right - _sinAngle * bottom;
				__rotatedBounds.y += __origin.y + _sinAngle * left  + _cosAngle * bottom;
			}
			else if (degrees < 270)
			{
				__rotatedBounds.x += __origin.x + _cosAngle * right - _sinAngle * top;
				__rotatedBounds.y += __origin.y + _sinAngle * right + _cosAngle * bottom;
			}
			else
			{
				__rotatedBounds.x += __origin.x + _cosAngle * left - _sinAngle * top;
				__rotatedBounds.y += __origin.y + _sinAngle * right + _cosAngle * top;
			}
			// temp var, in case input rect is the output rect
			final newHeight:Float  = Math.abs(_cosAngle * __rotatedBounds.height) + Math.abs(_sinAngle * __rotatedBounds.width );
			__rotatedBounds.width  = Math.abs(_cosAngle * __rotatedBounds.width ) + Math.abs(_sinAngle * __rotatedBounds.height);
			__rotatedBounds.height = newHeight;
		}
		return __rotatedBounds;
	}

	@:noCompletion extern inline function __get__rotated__matrix():FlxMatrix
	{
		__update__trig();
		__angleMatrix.identity();
		__angleMatrix.translate(-width * 0.5, -height * 0.5);
		__angleMatrix.scale(scaleX, scaleY);
		// __angleMatrix.scale(totalScaleX, totalScaleY);
		__angleMatrix.rotateWithTrig(_cosAngle, _sinAngle);
		__angleMatrix.translate(width * 0.5, height * 0.5);
		__angleMatrix.translate(flashSprite.x - _flashOffset.x, flashSprite.y - _flashOffset.y);
		__angleMatrix.scale(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y);
		return __angleMatrix;
	}	

	@:noCompletion extern inline function __update__trig()
	{
		if (_angleChanged)
		{
			final radians = (angle % 360) * flixel.math.FlxAngle.TO_RAD;
			_sinAngle = Math.sin(radians);
			_cosAngle = Math.cos(radians);
		}
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