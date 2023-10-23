package objects;

import flixel.math.FlxPoint;
import flixel.math.FlxRect;

class HealthBar extends FlxSpriteGroup
{
	public var leftBar:FlxSprite;
	public var rightBar:FlxSprite;
	public var bg:FlxSprite;
	public var valueFunction:Void->Float = function() return 0;
	public var percent/*(default, set)*/:Float = 0;
	public var bounds:Dynamic = {min: 0, max: 1};
	public var leftToRight(default, set):Bool = true;
	public var barCenter(default, null):Float = 0;

	// you might need to change this if you want to use a custom bar
	public var barWidth(default, set):Int = 1;
	public var barHeight(default, set):Int = 1;
	public var barOffset:FlxPoint = new FlxPoint(3, 3);

	public function new(x:Float, y:Float, image:String = 'healthBar', valueFunction:Void->Float = null, boundX:Float = 0, boundY:Float = 1)
	{
		super(x, y);
		
		if(valueFunction != null) this.valueFunction = valueFunction;
		setBounds(boundX, boundY);
		
		bg = new FlxSprite(0, 0, Paths.image(image));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		barWidth = Std.int(bg.width - 6);
		barHeight = Std.int(bg.height - 6);

		leftBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height));
		leftBar.antialiasing = antialiasing = ClientPrefs.data.antialiasing;

		rightBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height));
		rightBar.color = FlxColor.BLACK;
		rightBar.antialiasing = ClientPrefs.data.antialiasing;

		add(leftBar);
		add(rightBar);
		add(bg);
		regenerateClips();
	}

	override function update(elapsed:Float) {
		var value:Null<Float> = FlxMath.remapToRange(FlxMath.bound(valueFunction(), bounds.min, bounds.max), bounds.min, bounds.max, 0, 100);
		var prevPercent:Float = percent;
		percent = (value != null ? value : 0);
		updateBar(prevPercent);
		super.update(elapsed);
	}

	public function setBounds(min:Float, max:Float)
	{
		bounds.min = min;
		bounds.max = max;
	}

	public function setColors(left:FlxColor, right:FlxColor)
	{
		leftBar.color = left;
		rightBar.color = right;
	}

	public function updateBar(?prevPercent:Float)
	{
		if(leftBar == null || rightBar == null) return;

		leftBar.setPosition(bg.x, bg.y);
		rightBar.setPosition(bg.x, bg.y);

		var leftSize:Float = FlxMath.lerp(0, barWidth, leftToRight ? percent / 100 : 1 - percent / 100);

		if(percent != prevPercent)
		{
			var rectLeft:FlxRect = leftBar.clipRect;
			var rectRight:FlxRect = rightBar.clipRect;

			rectLeft.width = leftSize;
			rectLeft.height = barHeight;
			rectLeft.x = barOffset.x;
			rectLeft.y = barOffset.y;

			rectRight.width = barWidth - leftSize;
			rectRight.height = barHeight;
			rectRight.x = barOffset.x + leftSize;
			rectRight.y = barOffset.y;

			// flixel is retarded
			leftBar.clipRect = rectLeft;
			rightBar.clipRect = rectRight;
		}

		barCenter = leftBar.x + leftSize + barOffset.x;
	}

	public function regenerateClips()
	{
		if(leftBar != null)
		{
			leftBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			leftBar.updateHitbox();
			leftBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		if(rightBar != null)
		{
			rightBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			rightBar.updateHitbox();
			rightBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		updateBar();
	}

	/*private function set_percent(value:Float)
	{
		var doUpdate:Bool = value != percent;
		percent = value;
		if(doUpdate) updateBar();
		return value;
	}*/

	private function set_leftToRight(value:Bool)
	{
		leftToRight = value;
		updateBar();
		return value;
	}

	private function set_barWidth(value:Int)
	{
		barWidth = value;
		regenerateClips();
		return value;
	}

	private function set_barHeight(value:Int)
	{
		barHeight = value;
		regenerateClips();
		return value;
	}
}