package states;

import states.MainMenuState.MainMenuOption;
import options.OptionsState;

class MainMenuPCState extends MusicBeatState
{
	static final optionShit:Array<MainMenuOption> = [
		["story_mode",	StoryMenuState.new],
		["freeplay",	FreeplayState.new],
		// #if ACHIEVEMENTS_ALLOWED
		["awards",		AchievementsMenuState.new],
		// #end
		["credits",		CreditsState.new],
		["options",		OptionsState.new, true]
	];
	static var curSelected = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;

	override public function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		Mods.loadTopMod();
		#end

		#if hxdiscord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Testin' shit ig", null);
		#end

		persistentUpdate = true;

		final ligma = new FlxSprite(Paths.image("mainMenuPC/ligmaballs"));
		ligma.setGraphicSize(FlxG.width, FlxG.height);
		ligma.updateHitbox();
		add(ligma);

		add(menuItems = new FlxTypedGroup());
		for (i => option in optionShit)
			menuItems.add(new FlxText(225, 140 + 33 * i, option.name, 32).setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 2)).alpha = .5;

		add(new FlxText(6, FlxG.height - 56, "NOT FINAL!!! (hi redar!)", 46).setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 4));
		changeItem();
		super.create();
	}

	var selected = false;

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		if (!selected)
		{
			final UP = controls.UI_UP_P;
			final WHEEL = FlxG.mouse.wheel != 0;
			if (WHEEL || UP || controls.UI_DOWN_P)
				changeItem(WHEEL ? -FlxG.mouse.wheel : (UP ? -1 : 1), WHEEL);

			if (controls.BACK)
			{
				selected = true;
				FlxG.sound.play(Paths.sound("cancelMenu"));
				MusicBeatState.switchState(MainMenuState.new);
			}
			else if (controls.ACCEPT)
			{
				selected = true;
				FlxG.sound.play(Paths.sound("confirmMenu"));

				final curOption = optionShit[curSelected];
				if (curOption.name == "options")
				{
					OptionsState.onPlayState = false;
					if (PlayState.SONG != null)
						PlayState.SONG.arrowSkin = PlayState.SONG.splashSkin = null;
				}

				if (curOption.preload)
					LoadingState.loadAndSwitchState(curOption.state);
				else
					MusicBeatState.switchState(curOption.state);
			}
		}
	}

	function changeItem(factor = 0, wheel = false)
	{
		if (factor != 0)
			FlxG.sound.play(Paths.sound("scrollMenu"), wheel ? .5 : 1);

		var item = menuItems.members[curSelected];
		item.alpha = .5;
		item.offset.x = 0;

		item = menuItems.members[curSelected = FlxMath.wrap(curSelected + factor, 0, optionShit.length-1)];
		item.alpha = 1;
		item.offset.x = -5;
	}
}