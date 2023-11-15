package objects;

import flixel.math.FlxPoint;
import flixel.math.FlxRect;

typedef BarBounds = {min:Float, max:Float}

class Bar extends FlxSpriteGroup
{
	public var leftBar:FlxSprite;
	public var rightBar:FlxSprite;
	public var bg:FlxSprite;
	
	public var bounds:BarBounds = {min: 0, max: 1};
	public var percent(default, set):Float = 0;
	public var leftToRight(default, set):Bool = true;

	// DEPRECATED!!!
	public var barCenter(get, never):Float;
	public var centerPoint(default, null):FlxPoint = FlxPoint.get();

	// you might need to change this if you want to use a custom bar
	public var barWidth(default, set):Int = 1;
	public var barHeight(default, set):Int = 1;
	public var barOffset:FlxPoint = FlxPoint.get(3, 3); // for optimisation purposes

	public var valueFunction:() -> Float;
	public var updateCallback:(value:Float, percent:Float) -> Void;

	public function new(x:Float, y:Float, image:String = 'healthBar', valueFunction:()->Float = null, boundMin:Float = 0, boundMax:Float = 1)
	{
		super(x, y);

		this.valueFunction = valueFunction != null ? valueFunction : function() return 0;
		setBounds(boundMin, boundMax);
		
		bg = new FlxSprite(0, 0, Paths.image(image));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		barWidth = Std.int(bg.width - barOffset.x * 2);
		barHeight = Std.int(bg.height - barOffset.y * 2);

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

	override function update(elapsed:Float)
	{
		var value:Null<Float> = FlxMath.remapToRange(FlxMath.bound(valueFunction(), bounds.min, bounds.max), bounds.min, bounds.max, 0, 100);
		percent = (value != null ? value : 0);
		//if(rightBar != null) rightBar.setPosition(bg.x, bg.y);
		//if(leftBar != null) leftBar.setPosition(bg.x, bg.y);
		super.update(elapsed);
	}

	override public function destroy()
	{
		barOffset.put();
		centerPoint.put();
		super.destroy();
	}

	public function setBounds(min:Float = 0, max:Float = 1)
	{
		bounds.min = min;
		bounds.max = max;
	}

	public function setColors(?left:FlxColor, ?right:FlxColor)
	{
		if (left != null)  leftBar.color = left;
		if (right != null) rightBar.color = right;
	}

	public function updateBar()
	{
		if(leftBar == null || rightBar == null) return;

		var leftSize:Float = FlxMath.lerp(0, barWidth, (leftToRight ? percent * 0.01 : 1 - percent * 0.01));

		var rectRight:FlxRect = rightBar.clipRect;
		rectRight.width = barWidth - leftSize;
		rectRight.height = barHeight;
		rectRight.x = barOffset.x + leftSize;
		rectRight.y = barOffset.y;

		var rectLeft:FlxRect = leftBar.clipRect;
		rectLeft.width = leftSize;
		rectLeft.height = barHeight;
		rectLeft.x = barOffset.x;
		rectLeft.y = barOffset.y;

		// flixel is retarded
		leftBar.clipRect = rectLeft;
		rightBar.clipRect = rectRight;

		centerPoint.set(leftBar.x + leftSize + barOffset.x, leftBar.y + leftBar.clipRect.height * 0.5 + barOffset.y);

		if(updateCallback != null)
		{
			var val:Null<Float> = valueFunction();
			updateCallback(val != null ? val : 0, percent);
		}
	}

	public function regenerateClips(backInPool:Bool = false)
	{
		if(leftBar != null)
		{
			leftBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			leftBar.updateHitbox();
			if (backInPool) leftBar.clipRect.put();
			leftBar.clipRect = FlxRect.get(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		if(rightBar != null)
		{
			rightBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			rightBar.updateHitbox();
			if (backInPool) rightBar.clipRect.put();
			rightBar.clipRect = FlxRect.get(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		updateBar();
	}

	private function set_percent(value:Float)
	{
		var doUpdate:Bool = value != percent;
		percent = value;
		if(doUpdate) updateBar();
		return value;
	}

	private function set_leftToRight(value:Bool)
	{
		leftToRight = value;
		updateBar();
		return value;
	}

	private function set_barWidth(value:Int)
	{
		barWidth = value;
		regenerateClips(true);
		return value;
	}

	private function set_barHeight(value:Int)
	{
		barHeight = value;
		regenerateClips(true);
		return value;
	}

	function get_barCenter():Float return centerPoint.x;

	override function set_x(Value:Float):Float // for dynamic center point update
	{
		var prevX:Float = x;
		super.set_x(Value);
		if (leftBar != null && exists && prevX != Value)
			centerPoint.x = leftBar.x + FlxMath.lerp(0, barWidth, leftToRight ? percent * 0.01 : 1 - percent * 0.01) + barOffset.x;
		return Value;
	}

	override function set_y(Value:Float):Float
	{
		var prevY:Float = y;
		super.set_y(Value);
		if (leftBar != null && exists && prevY != Value)
			centerPoint.y = leftBar.y + leftBar.clipRect.height * 0.5 + barOffset.y;
		return Value;
	}
}