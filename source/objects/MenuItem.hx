package objects;

class MenuItem extends FlxSprite
{
	public var position:Int = 0;
	public var selected(default, set):Bool = false;
	public var onChange:Bool->Void;
	public var onSelect:()->Void;

	public var useFlicker:Bool = true; 
	public var isFlashing(default, set):Bool = false;
	public var flashColor:Int = 0xFF33ffff;
	public var flashFrame:Int = 6;

	var _flashElapsed:Float = 0.0;

	public function new(?x:Float, ?y:Float, ?image:String/*, ?onChange:Bool->Void, ?onSelect:()->Void*/)
	{
		super(x, y, (image == null ? null : Paths.image(image)));
		antialiasing = ClientPrefs.data.antialiasing;
		// this.onChange = onChange;
		// this.onSelect = onSelect;
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (isFlashing)
		{
			_flashElapsed += elapsed;

			final flashState = ((_flashElapsed * FlxG.updateFramerate) % flashFrame > flashFrame * 0.5);
			if (useFlicker)
				visible = flashState;
			else
				color = flashState ? FlxColor.WHITE : flashColor;
		}
	}

	inline function set_selected(select:Bool):Bool
	{
		if (onChange != null)
			onChange(select);

		return selected = select;
	}

	inline function set_isFlashing(flashing:Bool):Bool
	{
		_flashElapsed = 0.0;
		if (useFlicker)
			visible = !flashing;
		else
			color = (flashing ? flashColor : FlxColor.WHITE);

		return isFlashing = flashing;
	}
}

class StoryMenuItem extends MenuItem
{
	public var targetY:Int = 0;

	public function new(?x:Float, ?y:Float, weekName:String/*, ?onChange:Bool->Void, ?onSelect:()->Void*/)
	{
		super(x, y, 'storymenu/$weekName'/*, onChange, onSelect*/);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		final __targetY = (targetY * 120) + 480;
		if (y != __targetY)
			y = CoolUtil.lerpElapsed(y, __targetY, 0.17);
	}
}

class AnimatedMenuItem extends MenuItem
{
	public function new(?x:Float, ?y:Float, image:String, ?idleName:String = 'basic', ?selectedName:String = 'white'/*, ?onChange:Bool->Void, ?onSelect:()->Void*/)
	{
		super(x, y/*, onChange, onSelect*/);
		frames = Paths.getSparrowAtlas(image);
		animation.addByPrefix('idle', idleName, 24);
		animation.addByPrefix('selected', selectedName, 24);
		animation.play('idle');
	}
}
