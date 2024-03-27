package objects;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxDestroyUtil;
import flixel.util.helpers.FlxBounds;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;

class Bar extends FlxSpriteGroup
{
	public var leftBar:BarSprite;
	public var rightBar:BarSprite;
	public var bg:FlxSprite;
	
	public var bounds:FlxBounds<Float>;
	public var percent(default, set):Float;
	public var leftToRight(default, set):Bool = true;
	public var smooth:Bool = true;

	// you might need to change this if you want to use a custom bar
	public var barWidth(default, set):Int;
	public var barHeight(default, set):Int;
	public var barOffset:FlxPoint = FlxPoint.get(3, 3); // for optimisation purposes
	public var centerPoint(default, null):FlxPoint = FlxPoint.get();

	public var valueFunction:() -> Float;
	public var updateCallback:(value:Float, percent:Float) -> Void;

	// internal value tracker
	var _value:Float;
	var _lerpFactor = 25.;

	// DEPRECATED!!!
	public var barCenter(get, never):Float;

	public function new(x = 0., y = 0., image = "healthBar", ?valueFunction:()->Float, boundMin = 0.0, boundMax = 1.0)
	{
		super(x, y);

		bg = new FlxSprite(Paths.image(image));
		leftBar = new BarSprite(bg.width, bg.height);
		rightBar = new BarSprite(bg.width, bg.height, FlxColor.BLACK);
		antialiasing = ClientPrefs.data.antialiasing;

		add(leftBar);
		add(rightBar);
		add(bg);

		bounds = new FlxBounds(boundMin, boundMax);
		this.valueFunction = valueFunction ?? () -> 0.0;
		_value = FlxMath.bound(this.valueFunction(), bounds.min, bounds.max);
		@:bypassAccessor
		{
			percent = FlxMath.remapToRange(_value, bounds.min, bounds.max, 0.0, 100.0);
			barWidth = Std.int(bg.width - barOffset.x * 2);
			barHeight = Std.int(bg.height - barOffset.y * 2);
		}
		regenerateClips();
	}

	override public function update(elapsed:Float)
	{
		_value = FlxMath.bound(valueFunction(), bounds.min, bounds.max);
		final percentValue = FlxMath.remapToRange(_value, bounds.min, bounds.max, 0, 100);
		percent = smooth && percent != percentValue ? FlxMath.lerp(percentValue, percent, Math.exp(-elapsed * _lerpFactor)) : percentValue;
		// rightBar.setPosition(bg.x, bg.y);
		// leftBar.setPosition(bg.x, bg.y);
		super.update(elapsed);
	}

	override public function destroy()
	{
		bounds = null;
		barOffset = FlxDestroyUtil.put(barOffset);
		centerPoint = FlxDestroyUtil.put(centerPoint);
		valueFunction = null;
		updateCallback = null;
		leftBar = null;
		rightBar = null;
		bg = null;
		super.destroy();
	}

	inline public function setBounds(min = 0., max = 1.):FlxBounds<Float>
	{
		return bounds.set(min, max);
	}

	inline public function setColors(?left:FlxColor, ?right:FlxColor)
	{
		if (left != null)
			leftBar.color = left;
		if (right != null)
			rightBar.color = right;
	}

	public function loadBarGraphics(bgGraphic:FlxGraphicAsset, ?leftBarGraphic:FlxGraphicAsset, ?rightBarGraphic:FlxGraphicAsset)
	{
		bg.loadGraphic(Paths.resolveGraphicAsset(bgGraphic));
		if (leftBarGraphic != null)
		{
			leftBar.loadGraphic((leftBarGraphic = Paths.resolveGraphicAsset(leftBarGraphic)));
			rightBar.loadGraphic(rightBarGraphic == null ? leftBarGraphic : Paths.resolveGraphicAsset(rightBarGraphic));
		}
	}

	public function updateBar()
	{
		final leftSize = FlxMath.lerp(0, barWidth, (leftToRight ? percent * 0.01 : 1 - percent * 0.01));

		final scaleX = Math.abs(scale.x);
		final scaleY = Math.abs(scale.y);

		// flixel is retarded
		rightBar.clipRect = rightBar.clipRect.set(
			(barOffset.x + leftSize) * scaleX,
			barOffset.y * scaleY,
			(barWidth - leftSize) * scaleX,
			barHeight * scaleY
		);
		leftBar.clipRect = leftBar.clipRect.set(
			barOffset.x * scaleX,
			barOffset.y * scaleY,
			leftSize * scaleX,
			barHeight * scaleY
		);

		centerPoint.set(leftBar.x + barOffset.x + leftSize * scaleX, leftBar.y + barOffset.y + barHeight * 0.5 * scaleY);

		if (updateCallback != null)
			updateCallback(_value, percent);
	}

	public function regenerateClips()
	{
		leftBar.setBarSize(bg.width, bg.height);
		// leftBar.setGraphicSize(bg.width, bg.height);
		leftBar.updateHitbox();
		// leftBar.clipRect = leftBar.clipRect.setSize(bg.width, bg.height);

		rightBar.setBarSize(bg.width, bg.height);
		// rightBar.setGraphicSize(bg.width, bg.height);
		rightBar.updateHitbox();
		// rightBar.clipRect = rightBar.clipRect.setSize(bg.width, bg.height);
		updateBar();
	}

	@:noCompletion inline function get_barCenter():Float
	{
		return centerPoint.x;
	}

	@:noCompletion inline function set_percent(value:Float)
	{
		if (percent != value)
		{
			percent = value;
			updateBar();
		}
		return value;
	}

	@:noCompletion inline function set_leftToRight(value:Bool)
	{
		leftToRight = value;
		updateBar();
		return value;
	}

	@:noCompletion inline function set_barWidth(value:Int)
	{
		barWidth = value;
		regenerateClips();
		// updateBar();
		return value;
	}

	@:noCompletion inline function set_barHeight(value:Int)
	{
		barHeight = value;
		regenerateClips();
		// updateBar();
		return value;
	}

	@:noCompletion override inline function set_x(value:Float):Float // for dynamic center point update
	{
		centerPoint.x += value - x;
		return super.set_x(value);
	}

	@:noCompletion override inline function set_y(value:Float):Float
	{
		centerPoint.y += value - y;
		return super.set_y(value);
	}

	@:noCompletion override function set_antialiasing(value:Bool):Bool
	{
		for (member in members)
			member.antialiasing = value;

		return antialiasing = value;
	}
}

class BarSprite extends FlxSprite
{
	inline static var __graphicKey = "__bar_sprite_graphic";

	public var barWidth(get, set):Float;
	public var barHeight(get, set):Float;

	@:noCompletion var __scale = FlxPoint.get();
	@:noCompletion var __originalScale = FlxPoint.get();

	@:noCompletion var __fakeScale = false;
	@:noCompletion var __drawingFakeScale = false;

	public function new(width = 300., height = 10., color = FlxColor.WHITE, ?graphic:FlxGraphicAsset)
	{
		super(graphic);
		if (graphic == null)
			makeGraphic(1, 1, FlxColor.WHITE, true, FlxG.bitmap.getUniqueKey(__graphicKey));

		this.color = color;
		setSize(width, height);
		setBarSize(width, height);
		clipRect = FlxRect.get(0, 0, width, height);
	}

	public function setBarSize(width:Float, height:Float):Void
	{
		__scale.set(width, height);
	}

	// scale sprite if it's graphic is 1x1 and upate hitbox afterwards 
	override public function updateHitbox():Void
	{
		if (!__fakeScale)
			return super.updateHitbox();

		__originalScale.copyFrom(scale);
		scale.scalePoint(__scale);
		super.updateHitbox();
		scale.copyFrom(__originalScale);
	}

	override public function destroy():Void
	{
		clipRect = FlxDestroyUtil.put(clipRect);
		super.destroy();
		__scale = FlxDestroyUtil.put(__scale);
		__originalScale = FlxDestroyUtil.put(__originalScale);
	}

	@:noCompletion override function drawComplex(camera:FlxCamera):Void
	{
		if (!__fakeScale)
			return super.drawComplex(camera);

		__drawingFakeScale = true;
		__originalScale.copyFrom(scale);
		scale.scalePoint(__scale);
		super.drawComplex(camera);
		scale.copyFrom(__originalScale);
		__drawingFakeScale = false;
	}

	override function transformWorldToPixelsSimple(worldPoint:FlxPoint, ?result:FlxPoint):FlxPoint
	{
		if (__drawingFakeScale)
			return super.transformWorldToPixelsSimple(worldPoint, result);

		__originalScale.copyFrom(scale);
		scale.scalePoint(__scale);
		final ret = super.transformWorldToPixelsSimple(worldPoint, result);
		scale.copyFrom(__originalScale);
		return ret;
	}

	override public function transformWorldToPixels(worldPoint:FlxPoint, ?camera:FlxCamera, ?result:FlxPoint):FlxPoint
	{
		if (__drawingFakeScale)
			return super.transformWorldToPixels(worldPoint, camera, result);

		__originalScale.copyFrom(scale);
		scale.scalePoint(__scale);
		final ret = super.transformWorldToPixels(worldPoint, camera, result);
		scale.copyFrom(__originalScale);
		return ret;
	}

	override function transformScreenToPixels(screenPoint:FlxPoint, ?camera:FlxCamera, ?result:FlxPoint):FlxPoint
	{
		if (__drawingFakeScale)
			return super.transformScreenToPixels(screenPoint, camera, result);

		__originalScale.copyFrom(scale);
		scale.scalePoint(__scale);
		final ret = super.transformScreenToPixels(screenPoint, camera, result);
		scale.copyFrom(__originalScale);
		return ret;
	}

	@:noCompletion override function set_graphic(value:FlxGraphic):FlxGraphic
	{
		__fakeScale = value != null && value.key.startsWith(__graphicKey);
		__drawingFakeScale = false;
		return super.set_graphic(value);
	}

	@:noCompletion override function set_clipRect(rect:FlxRect):FlxRect
	{
		if (rect != null)
		{
			var scaleX = scale.x;
			var scaleY = scale.y;
			if (__fakeScale)
			{
				scaleX *= __scale.x;
				scaleY *= __scale.y;
			}

			if ((scaleX = Math.max(FlxPoint.EPSILON, Math.abs(scaleX))) != 1)
			{
				rect.x /= scaleX;
				rect.width /= scaleX;
			}
			if ((scaleY = Math.max(FlxPoint.EPSILON, Math.abs(scaleY))) != 1)
			{
				rect.y /= scaleY;
				rect.height /= scaleY;
			}
		}
		clipRect = rect;
		if (frames != null)
			frame = frames.frames[animation.frameIndex];

		return rect;
	}

	@:noCompletion override inline function set_width(value:Float):Float
	{
		return width = value;
	}

	@:noCompletion override inline function set_height(value:Float):Float
	{
		return height = value;
	}

	@:noCompletion inline function get_barWidth():Float
	{
		return __scale.x;
	}

	@:noCompletion inline function set_barWidth(value:Float):Float
	{
		return __scale.x = value;
	}

	@:noCompletion inline function get_barHeight():Float
	{
		return __scale.x;
	}

	@:noCompletion inline function set_barHeight(value:Float):Float
	{
		return __scale.x = value;
	}
}
