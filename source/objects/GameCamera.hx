package objects;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;

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
	public var renderAngle(default, set):Bool;

	/**
		Pauses fx and camera movement.
	**/
	public var paused:Bool;

	// okay i actually optimized it???? (kinda)
	@:noCompletion var __tweenTimer = 0.0;

	@:noCompletion var _angleChanged = false;
	@:noCompletion var _sinAngle = 0.0;
	@:noCompletion var _cosAngle = 1.0;

	// helpers for fixing render on camera with angle applied
	@:noCompletion var _shakeOffset = FlxPoint.get();
	@:noCompletion var _rotatedBounds = FlxRect.get();
	@:noCompletion var _rotatedMatrix:FlxMatrix;
	@:noCompletion var _matrixDirty = false;

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
			updateShake(elapsed);
			updateFlash(elapsed);
			updateFade(elapsed);
		}

		flashSprite.filters = filtersEnabled ? filters : null;

		if (FlxG.renderTile)
		{
			flashSprite.rotation = renderAngle ? 0.0 : angle;
			__update__matrix(renderAngle);
		}
	}

	override public function destroy()
	{
		_rotatedMatrix = null;
		_rotatedBounds = FlxDestroyUtil.put(_rotatedBounds);
		_shakeOffset = FlxDestroyUtil.put(_shakeOffset);
		super.destroy();
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
			// drawing rect with these parameters to avoid light lines at the top and left of the camera,
			// which could appear while cameras fading
			targetGraphics.drawRect(bounds.x - 1, bounds.y - 1, bounds.width + 2, bounds.height + 2);
			targetGraphics.endFill();
		}
	}

	override public function onResize()
	{
		_matrixDirty = true;
		super.onResize();
	}

	override public function containsRect(rect:FlxRect):Bool
	{
		return __get__bounds().overlaps(rect);
	}

	override function updateShake(elapsed:Float):Void
	{
		if (_fxShakeDuration > 0)
		{
			_shakeOffset.set();
			_matrixDirty = true;
			_fxShakeDuration -= elapsed;
			if (_fxShakeDuration <= 0)
			{
				if (_fxShakeComplete != null)
				{
					_fxShakeComplete();
				}
			}
			else // TODO: fix shake on renderAngle
			{
				// if (renderAngle)
				//	__update__trig();

				var shakePixels:Float;
				final pixelPerfect = pixelPerfectShake == null ? pixelPerfectRender : pixelPerfectShake;
				if (_fxShakeAxes.x)
				{
					shakePixels = FlxG.random.float(-1, 1) * _fxShakeIntensity * width;
					if (pixelPerfect)
						shakePixels = Math.round(shakePixels);
					// if (renderAngle)
					//	shakePixels *= _cosAngle;
					
					_shakeOffset.x = shakePixels * zoom * FlxG.scaleMode.scale.x;
					flashSprite.x += _shakeOffset.x;
				}
				
				if (_fxShakeAxes.y)
				{
					shakePixels = FlxG.random.float(-1, 1) * _fxShakeIntensity * height;
					if (pixelPerfect)
						shakePixels = Math.round(shakePixels);
					// if (renderAngle)
					//	shakePixels *= _sinAngle;
					
					_shakeOffset.y = shakePixels * zoom * FlxG.scaleMode.scale.y;
					flashSprite.y += _shakeOffset.y;
				}
			}
		}
	}

	@:noCompletion extern inline function __get__bounds():FlxRect
	{
		_rotatedBounds.set(viewMarginLeft - _shakeOffset.x, viewMarginTop - _shakeOffset.y, viewWidth, viewHeight);
		return (renderAngle ? __get__rotated__bounds() : _rotatedBounds);
	}

	@:noCompletion extern inline function __get__rotated__bounds():FlxRect
	{
		var degrees = angle % 360;
		if (degrees != 0)
		{
			__update__trig();

			final centerX = _rotatedBounds.width  * 0.5;
			final centerY = _rotatedBounds.height * 0.5;
			final left    = -centerX;
			final top     = -centerY;
			final right   = -centerX + _rotatedBounds.width;
			final bottom  = -centerY + _rotatedBounds.height;

			if (degrees < 0)
				degrees += 360;

			switch (Math.floor(degrees * 0.0111111111111111)) // / 90
			{
				case 0: // < 90
					_rotatedBounds.x += centerX + _cosAngle * left - _sinAngle * bottom;
					_rotatedBounds.y += centerY + _sinAngle * left + _cosAngle * top;

				case 1: // < 180
					_rotatedBounds.x += centerX + _cosAngle * right - _sinAngle * bottom;
					_rotatedBounds.y += centerY + _sinAngle * left  + _cosAngle * bottom;

				case 2: // < 270
					_rotatedBounds.x += centerX + _cosAngle * right - _sinAngle * top;
					_rotatedBounds.y += centerY + _sinAngle * right + _cosAngle * bottom;

				case 3: // < 360
					_rotatedBounds.x += centerX + _cosAngle * left  - _sinAngle * top;
					_rotatedBounds.y += centerY + _sinAngle * right + _cosAngle * top;
			}

			final newHeight       = Math.abs(_cosAngle * _rotatedBounds.height) + Math.abs(_sinAngle * _rotatedBounds.width );
			_rotatedBounds.width  = Math.abs(_cosAngle * _rotatedBounds.width ) + Math.abs(_sinAngle * _rotatedBounds.height);
			_rotatedBounds.height = newHeight;
		}
		return _rotatedBounds;
	}

	@:noCompletion extern inline function __update__matrix(__rotate:Bool)
	{
		// maybe try updating matrix less frequently???
		if (_matrixDirty)
		{
			if (_rotatedMatrix == null)
				_rotatedMatrix = new FlxMatrix();

			// i have no fucking idea what this actually does but it sure does something - rich
			_rotatedMatrix.identity();
			_rotatedMatrix.translate(-width * 0.5, -height * 0.5);
			_rotatedMatrix.scale(scaleX, scaleY);
			if (__rotate)
			{
				__update__trig();
				_rotatedMatrix.rotateWithTrig(_cosAngle, _sinAngle);
			}
			_rotatedMatrix.translate(width * 0.5, height * 0.5);
			_rotatedMatrix.scale(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y);
			_rotatedMatrix.translate(_shakeOffset.x, _shakeOffset.y);

			canvas.transform.matrix = _rotatedMatrix;
			_matrixDirty = false;
		}
	}

	@:noCompletion extern inline function __update__trig()
	{
		if (_angleChanged)
		{
			final degrees = angle % 360;
			final radians = (degrees < 0 ? degrees + 360 : degrees) * flixel.math.FlxAngle.TO_RAD;
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

	@:noCompletion inline function set_renderAngle(bool:Bool):Bool
	{
		if (renderAngle != bool)
			_matrixDirty = true;

		return renderAngle = bool;
	}

	@:noCompletion override function set_angle(angle:Float):Float
	{
		if (this.angle != angle)
		{
			_angleChanged = true;
			if (renderAngle)
				_matrixDirty = true;
		}
		return this.angle = angle;
	}
}