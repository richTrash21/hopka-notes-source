package;

import flixel.addons.transition.FlxTransitionableState;
import states.FlashingState;

// THIS IS FOR INITIALIZING STUFF BECAUSE FLIXEL HATES INITIALIZING STUFF IN MAIN
// GO TO MAIN FOR GLOBAL PROJECT/OPENFL STUFF
// CODE BY Rudyrue (https://github.com/ShadowMario/FNF-PsychEngine/pull/13695)
class Init extends flixel.FlxState
{
	override function create():Void
	{
		sound = FlxG.sound.load(Paths.sound("haxe_intro"));
		final atlas = Paths.getSparrowAtlas("startup_assets");

		text = new FlxSprite(446, 45);
		text.antialiasing = ClientPrefs.data.antialiasing;
		text.frames = atlas;
		text.animation.addByPrefix("text", "powered-by", 24);
		text.animation.play("text");
		text.animation.finish();
		// text.screenCenter(X);
		text.moves = false;
		text.precache();

		hxLogo = new FlxSprite(244, 180);
		hxLogo.antialiasing = ClientPrefs.data.antialiasing;
		hxLogo.frames = atlas;
		hxLogo.animation.addByPrefix("haxe", "haxeflixel_anim", 24);
		hxLogo.animation.getByName("haxe").loopPoint = 3;
		hxLogo.screenCenter(X);
		hxLogo.moves = false;
		hxLogo.precache();

		hxOutline = new FlxSprite(hxLogo.x + 5, hxLogo.y - 5);
		hxOutline.antialiasing = ClientPrefs.data.antialiasing;
		hxOutline.frames = atlas;
		hxOutline.animation.addByIndices("haxe", "haxeflixel_anim", [3, 4, 5], "", 0);
		hxOutline.moves = false;
		hxOutline.precache();

		add(hxOutline).visible = false;
		add(hxLogo).visible = false;
		add(text).visible = false;

		timedEvents = [
			[0.5833, () ->
			{
				sound.play();
				text.visible = true;
				text.animation.play("text");
			}],
			[1.25, () ->
			{
				hxLogo.visible = true;
				hxLogo.animation.play("haxe");
			}],
			[1.2917, () ->
			{
				hxOutline.visible = true;
				hxOutline.animation.play("haxe");
				tween = FlxTween.tween(hxOutline, {x: 266, y: 202}, 0.9166, {ease: FlxEase.bounceOut, onComplete: (_) -> tween = null});
				upateOutlineColor();
			}],
			[2.5833, FlxG.camera.fade.bind(FlxColor.BLACK, 1.375, false, null, false)],
			[4, () -> leave()]
		];
	}

	static var hxPalette:Array<FlxColor> = [0x00b922, 0xffc132, 0xf5274e, 0x3641ff, 0x04cdfb];
	static var colorTimeLen = 0.1667;
	var colorTime = 0.0;
	var curColor = -1;

	var tween:FlxTween;
	var sound:FlxSound;
	var text:FlxSprite;
	var hxLogo:FlxSprite;
	var hxOutline:FlxSprite;

	var time = 0.0;
	var startedScene:Bool;
	var timedEvents:Array<TimedEvent>;

	override public function update(elapsed:Float)
	{
		if (Controls.instance.ACCEPT || Controls.instance.BACK || Controls.instance.PAUSE)
		{
			super.update(elapsed);
			return leave();
		}

		time += elapsed;
		while (timedEvents.length != 0 && time >= timedEvents[0].time)
			timedEvents.shift().func();

		if (hxOutline.visible)
		{
			colorTime += elapsed;
			while (colorTime >= colorTimeLen)
			{
				upateOutlineColor();
				colorTime -= colorTimeLen;
			}
		}

		super.update(elapsed);
	}

	extern inline function upateOutlineColor()
	{
		curColor = ++curColor % hxPalette.length;
		hxOutline.color = hxPalette[curColor];
		final anim = hxOutline.animation.curAnim;
		anim.curFrame = ++anim.curFrame % anim.numFrames;
	}

	override public function destroy()
	{
		if (tween != null)
			tween.cancel();
		super.destroy();
		timedEvents = null;
		hxOutline = null;
		hxLogo = null;
		sound = null;
		tween = null;
		text = null;
	}

	@:noCompletion extern inline function leave()
	{
		var switchTo:flixel.util.typeLimit.NextState = Main.initialState;
		if (FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			switchTo = FlashingState.new;
		}
		FlxG.switchState(FlxG.save.data.isDoised ? states.DoiseRoomLMAO.new : switchTo);
	}
}

@:noCompletion private abstract TimedEvent(__TimedEventType) from __TimedEventType to __TimedEventType
{
	public var time(get, never):Float;
	public var func(get, never):()->Void;

	@:noCompletion inline function get_time():Float     return this[0];
	@:noCompletion inline function get_func():()->Void  return this[1];
}

@:noCompletion private typedef __TimedEventType = Array<haxe.extern.EitherType<Float, ()->Void>>;
