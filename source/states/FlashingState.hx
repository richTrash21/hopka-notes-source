package states;

import flixel.addons.transition.FlxTransitionableState;

class FlashingState extends flixel.FlxState
{
	public static var leftState = false;
	inline static final WARN_TEXT = "Hey, watch out!
This Mod contains some flashing lights!
Press ENTER to ignore this message.
Press ESCAPE to disable them now or go to Options Menu.
You've been warned!";

	override function create()
	{
		if (leftState)
			return __next();

		add(new FlxText(0, 0, FlxG.width,WARN_TEXT, 32).setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER).screenCenter());
	}

	override function update(elapsed:Float)
	{
		if (!leftState)
		{
			final back = Controls.instance.BACK;
			if (Controls.instance.ACCEPT || back)
			{
				FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = leftState = true;
				if (back)
				{
					ClientPrefs.data.flashing = false;
					ClientPrefs.saveSettings();
					FlxG.sound.play(Paths.sound("confirmMenu"));
					flixel.effects.FlxFlicker.flicker(cast members[0], 1, .1, false, true, (_) -> new FlxTimer().start(.5, (_) -> __next()));
				}
				else
				{
					FlxG.sound.play(Paths.sound("cancelMenu"));
					FlxG.camera.fade(() -> __next());
				}
			}
		}
		super.update(elapsed);
	}

	@:noCompletion extern inline function __next()
	{
		MusicBeatState.switchState(Main.game.initialState);
	}
}
