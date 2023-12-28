package objects;

import flixel.util.FlxDestroyUtil;
import flixel.util.helpers.FlxBounds;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;

class Bar extends FlxSpriteGroup
{
	public var leftBar:FlxSprite;
	public var rightBar:FlxSprite;
	public var bg:FlxSprite;
	
	public var bounds:FlxBounds<Float> = new FlxBounds<Float>(0.0);
	public var percent(default, set):Float = 0.0;
	public var leftToRight(default, set):Bool = true;
	public var smooth:Bool = true;

	// DEPRECATED!!!
	public var barCenter(get, never):Float;
	public var centerPoint(default, null):FlxPoint = FlxPoint.get();
	@:noCompletion inline function get_barCenter():Float return centerPoint.x;

	// you might need to change this if you want to use a custom bar
	public var barWidth(default, set):Int = 1;
	public var barHeight(default, set):Int = 1;
	public var barOffset:FlxPoint = FlxPoint.get(3, 3); // for optimisation purposes

	public var valueFunction:() -> Float;
	public var updateCallback:(value:Float, percent:Float) -> Void;

	// internal value tracker
	var _value:Float;

	public function new(x:Float, y:Float, image:String = 'healthBar', ?valueFunction:()->Float, boundMin:Float = 0.0, boundMax:Float = 1.0)
	{
		super(x, y);

		this.valueFunction = valueFunction ?? function() return 0.0;
		setBounds(boundMin, boundMax);

		_value = FlxMath.bound(this.valueFunction(), bounds.min, bounds.max);
		percent = FlxMath.remapToRange(_value, bounds.min, bounds.max, 0.0, 100.0);
		
		bg = new FlxSprite(Paths.image(image));
		barWidth = Std.int(bg.width - barOffset.x * 2);
		barHeight = Std.int(bg.height - barOffset.y * 2);

		leftBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height));

		rightBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height));
		rightBar.color = FlxColor.BLACK;

		antialiasing = ClientPrefs.data.antialiasing;

		add(leftBar);
		add(rightBar);
		add(bg);
		regenerateClips();
	}

	public function setBounds(min:Float = 0, max:Float = 1):FlxBounds<Float>
		return bounds.set(min, max);

	override function update(elapsed:Float)
	{
		_value = FlxMath.bound(valueFunction(), bounds.min, bounds.max);
		final percentValue:Float = FlxMath.remapToRange(_value, bounds.min, bounds.max, 0, 100);
		percent = smooth ? FlxMath.lerp(percent, percentValue, elapsed * 25) : percentValue;
		//if (rightBar != null) rightBar.setPosition(bg.x, bg.y);
		//if (leftBar != null)  leftBar.setPosition(bg.x, bg.y);
		super.update(elapsed);
	}

	override public function destroy()
	{
		bounds = null;
		barOffset = FlxDestroyUtil.put(barOffset);
		centerPoint = FlxDestroyUtil.put(centerPoint);
		leftBar.clipRect = FlxDestroyUtil.put(leftBar.clipRect);
		rightBar.clipRect = FlxDestroyUtil.put(rightBar.clipRect);
		super.destroy();
	}

	public function setColors(?left:FlxColor, ?right:FlxColor)
	{
		if (left != null)  leftBar.color = left;
		if (right != null) rightBar.color = right;
	}

	public function updateBar()
	{
		if (leftBar == null || rightBar == null) return;

		final leftSize:Float = FlxMath.lerp(0, barWidth, (leftToRight ? percent * 0.01 : 1 - percent * 0.01));

		final rectRight:FlxRect = rightBar.clipRect;
		rectRight.width = barWidth - leftSize;
		rectRight.height = barHeight;
		rectRight.x = barOffset.x + leftSize;
		rectRight.y = barOffset.y;

		final rectLeft:FlxRect = leftBar.clipRect;
		rectLeft.width = leftSize;
		rectLeft.height = barHeight;
		rectLeft.x = barOffset.x;
		rectLeft.y = barOffset.y;

		// flixel is retarded
		leftBar.clipRect = rectLeft;
		rightBar.clipRect = rectRight;

		centerPoint.set(leftBar.x + leftSize + barOffset.x, leftBar.y + leftBar.clipRect.height * 0.5 + barOffset.y);

		if (updateCallback != null)
			updateCallback(_value, percent);
	}

	public function regenerateClips()
	{
		if (leftBar == null && rightBar == null) return;

		final width = Std.int(bg.width);
		final height = Std.int(bg.height);
		if (leftBar != null)
		{
			leftBar.setGraphicSize(width, height);
			leftBar.updateHitbox();
			if (leftBar.clipRect == null)
				leftBar.clipRect = FlxRect.get(0, 0, width, height);
			else
				leftBar.clipRect.set(0, 0, width, height);
		}
		if (rightBar != null)
		{
			rightBar.setGraphicSize(width, height);
			rightBar.updateHitbox();
			if (rightBar.clipRect == null)
				rightBar.clipRect = FlxRect.get(0, 0, width, height);
			else
				rightBar.clipRect.set(0, 0, width, height);
		}
		updateBar();
	}

	@:noCompletion inline function set_percent(value:Float)
	{
		final doUpdate:Bool = value != percent;
		percent = value;
		if (doUpdate) updateBar();
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
		return value;
	}

	@:noCompletion inline function set_barHeight(value:Int)
	{
		barHeight = value;
		regenerateClips();
		return value;
	}

	@:noCompletion override inline function set_x(Value:Float):Float // for dynamic center point update
	{
		final prevX:Float = x;
		super.set_x(Value);
		centerPoint.x += Value - prevX;
		return Value;
	}

	@:noCompletion override inline function set_y(Value:Float):Float
	{
		final prevY:Float = y;
		super.set_y(Value);
		centerPoint.y += Value - prevY;
		return Value;
	}

	@:noCompletion override inline function set_antialiasing(Antialiasing:Bool):Bool
	{
		for (member in members)
			member.antialiasing = Antialiasing;

		return antialiasing = Antialiasing;
	}
}