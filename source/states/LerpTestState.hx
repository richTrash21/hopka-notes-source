package states;

import flixel.text.FlxBitmapText;
import backend.StateTransition;

class LerpTestState extends backend.BaseState
{
	static final START_POS = FlxPoint.get(80, 80);
	static final TARGET_POS = FlxPoint.get(1200, 640);
	inline static final PRECISION = 1 / 100;

	static var curLerp = 0;
	static var curSpeed = 0.5;
	static final lerpModes:Array<LerpFunc> = [
		(a, b, t, e) -> FlxMath.lerp(a, b, 1 - Math.pow(2, -e / (-t / (Math.log(PRECISION) / Math.log(2))))),
		(a, b, t, e) -> FlxMath.lerp(a, b, 1 - Math.pow(PRECISION, e / t)),
		(a, b, t, e) -> FlxMath.lerp(a, b, 1 - Math.pow(1 - t, e * 60))
	];

	var object:FlxSprite;
	var pos:FlxBitmapText;

	override public function create()
	{
		StateTransition.skipNextTransOut = StateTransition.skipNextTransIn = true;
		FlxG.camera.bgColor = 0xFF999999;

		add(object = new FlxSprite(START_POS.x, START_POS.y).makeGraphic(80, 80, FlxColor.RED));
		object.offset.set(object.width * 0.5, object.height * 0.5);
		object.active = false;

		add(pos = new FlxBitmapText(10, "ass"));
		pos.scale.set(4, 4);
		pos.updateHitbox();
		pos.y = FlxG.height - pos.height - 10;
		pos.active = false;

		final ass = 1 / 255;
		trace(ass);

		Main.fpsVar.watch("Current Mode", ()->curLerp);
		Main.fpsVar.watch("Current Speed", ()->curSpeed);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		final notSameX = object.x != TARGET_POS.x;
		final notSameY = object.y != TARGET_POS.y;
		if (notSameX || notSameY)
		{
			final lerpMode = lerpModes[curLerp];
			if (notSameX)
				object.x = lerpMode(object.x, TARGET_POS.x, curSpeed, elapsed);
			if (notSameY)
				object.y = lerpMode(object.y, TARGET_POS.y, curSpeed, elapsed);
		}

		if (FlxG.keys.justPressed.LEFT)
			updateMode(-1);
		else if (FlxG.keys.justPressed.RIGHT)
			updateMode(1);

		if (FlxG.keys.justPressed.DOWN)
			updateSpeed(-0.1);
		else if (FlxG.keys.justPressed.UP)
			updateSpeed(0.1);

		if (FlxG.keys.justPressed.R)
			resetPos();

		pos.text = "(x: " + FlxMath.roundDecimal(object.x, 5) + ", y: " + FlxMath.roundDecimal(object.y, 5) + ")";

		if (FlxG.keys.justPressed.ESCAPE)
			FlxG.switchState(MainMenuState.new);
	}

	function updateMode(add = 0)
	{
		curLerp = (curLerp + add) % lerpModes.length;
		if (curLerp < 0)
			curLerp += lerpModes.length;

		resetPos();
	}

	function updateSpeed(add = 0.0)
	{
		curSpeed = FlxMath.bound(curSpeed + add, 0, 1);
		resetPos();
	}

	inline function resetPos()
	{
		object.x = START_POS.x;
		object.y = START_POS.y;
	}
}

typedef LerpFunc = (a:Float, b:Float, t:Float, e:Float) -> Float;
