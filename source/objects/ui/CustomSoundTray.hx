package objects.ui;

class CustomSoundTray extends flixel.system.ui.FlxSoundTray
{
	@:keep public function new()
	{
		super();

		// это рофлс
		#if debug
		volumeUpSound = "assets/sounds/metal";
		volumeDownSound = "assets/sounds/lego";
		#else
		volumeUpSound = "assets/sounds/up_volume";
		volumeDownSound = "assets/sounds/down_volume";
		#end
	}

	/** This function updates the soundtray object. **/
	override public function update(MS:Float):Void
	{
		final elapsed = MS * 0.001;

		// Animate sound tray thing
		if (_timer > 0.0)
		{
			_timer -= elapsed;

			if (y < 0.0)
				y = Math.min(y + elapsed * height * 30, 0.0);
		}
		else if (y > -height)
		{
			y -= elapsed * height * 10;

			if (y <= -height)
			{
				visible = false;
				active = false;

				#if FLX_SAVE
				// Save sound preferences
				// 😭😭
				// https://cdn.discordapp.com/attachments/1219255780172107814/1228390649800429619/image.png?ex=662bdef1&is=661969f1&hm=a4e56106582ab2aff9c393d3755b567c5353980082ca2747cce923eb726267a4&
				// if (FlxG.save.isBound)
				// {
					FlxG.save.data.mute = FlxG.sound.muted;
					FlxG.save.data.volume = FlxG.sound.volume;
					FlxG.save.flush();
				// }
				#end
			}
		}
	}

	/**
		Makes the little volume tray slide out.
		@param	up Whether the volume is increasing.
	**/
	override public function show(up = false):Void
	{
		if (!silent)
		{
			final sound = flixel.system.FlxAssets.getSound(up ? volumeUpSound : volumeDownSound);
			if (sound != null)
			{
				final beep = FlxG.sound.load(sound);
				beep.onComplete = () -> __sound__on__complete(beep);
				#if FLX_PITCH
				beep.pitch = FlxMath.lerp(0.9, 1.1, FlxG.sound.volume);
				#end
				beep.play();

				// need this so that FlxG.sound.pause() won't affect this sound
				// and so sound won't cut off durring state transition
				// will put it back after it finished playing
				// pretty stupid solution but idk it works ig - rich
				FlxG.sound.list.remove(beep);
			}
		}

		if (!visible)
			y = -height;

		visible = true;
		active = true;
		_timer = 1.0;

		final globalVolume = FlxG.sound.muted ? 0 : Math.round(FlxG.sound.volume * 10);
		for (i in 0..._bars.length)
			_bars[i].alpha = i < globalVolume ? 1.0 : 0.5;
	}

	@:noCompletion extern inline static function __sound__on__complete(__sound:FlxSound)
	{
		// back in group for recycling
		FlxG.sound.list.add(__sound);
		__sound.onComplete = null;
	}
}