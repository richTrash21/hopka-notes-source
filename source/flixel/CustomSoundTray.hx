package flixel;

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
	@:access(flixel.FlxGame._lostFocus)
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
			y -= elapsed * height * 5;

			if (y <= -height)
			{
				visible = false;
				active = false;

				#if FLX_SAVE
				// Save sound preferences
				// isBound breaks sometimes idk why 😭😭
				// if (FlxG.save.isBound)
				// {
					FlxG.save.data.mute = FlxG.sound.muted;
					FlxG.save.data.volume = (ClientPrefs.data.lostFocusDeafen && FlxG.game._lostFocus) ? FlxG.sound.volume * 2 : FlxG.sound.volume;
					FlxG.save.flush();
				// }
				#end
			}
		}
		alpha = y == 0.0 ? 1.0 : 1.0 - (y / -(height * 0.6));
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
				beep.pitch = 0.9 + 0.3 * FlxG.sound.volume;
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
		for (i => bar in _bars)
			bar.alpha = i < globalVolume ? 1.0 : 0.5;
	}

	override public function screenCenter()
	{
		scaleX = Math.min(FlxG.scaleMode.scale.x + 1, _defaultScale);
		scaleY = Math.min(FlxG.scaleMode.scale.y + 1, _defaultScale);
		x = (0.5 * (FlxG.stage.stageWidth - _width * scaleX) - FlxG.game.x);
	}

	@:noCompletion extern inline static function __sound__on__complete(__sound:FlxSound)
	{
		// back in group for recycling
		FlxG.sound.list.add(__sound);
		__sound.onComplete = null;
	}
}