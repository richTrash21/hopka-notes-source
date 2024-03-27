package options;

import flixel.util.FlxDestroyUtil;
import flixel.FlxSubState;

class OptionsState extends MusicBeatState
{
	static final menuOptions = ["Note Colors", "Controls", "Adjust Delay and Combo", "Graphics", "Visuals and UI", "Gameplay"];
	static var curSelected = 0;

	public static var onPlayState = false;
	public static final BG_COLOR:FlxColor = 0xFFEA71FD;

	inline function openSelectedSubstate(label:String)
	{
		switch (label)
		{
			case "Note Colors":				openSubState(new options.NotesSubState());
			case "Controls":				openSubState(new options.ControlsSubState());
			case "Graphics":				openSubState(new options.GraphicsSettingsSubState());
			case "Visuals and UI":			openSubState(new options.VisualsUISubState());
			case "Gameplay":				openSubState(new options.GameplaySettingsSubState());
			case "Adjust Delay and Combo":	MusicBeatState.switchState(options.NoteOffsetState.new);
		}
	}

	var grpOptions:FlxTypedGroup<Alphabet>;
	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var __genocide = false; // UNDERTALE REFERENCE!!!!!!!

	override function create()
	{
		#if hxdiscord_rpc
		DiscordClient.changePresence("Options Menu", null);
		#end

		final bg = new FlxSprite(Paths.image("menuDesat"));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = BG_COLOR;
		bg.active = false;
		add(bg.screenCenter());

		add(grpOptions = new FlxTypedGroup<Alphabet>());

		for (i in 0...menuOptions.length)
		{
			final optionText = new Alphabet(0, 0, menuOptions[i], true);
			optionText.screenCenter().y += (100 * (i - (menuOptions.length * .5))) + 50;
			grpOptions.add(optionText);
		}

		add(selectorLeft = new Alphabet(0, 0, ">", true));
		add(selectorRight = new Alphabet(0, 0, "<", true));

		changeSelection();
		ClientPrefs.saveSettings();

		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		if (__genocide)
		{
			grpOptions.forEach((option) -> option.revive());
			selectorRight.revive();
			selectorLeft.revive();
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		super.openSubState(SubState);
		if (__genocide)
		{
			grpOptions.forEach((option) -> option.kill());
			selectorRight.kill();
			selectorLeft.kill();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		final UP = controls.UI_UP_P;
		if (UP || controls.UI_DOWN_P)
			changeSelection(UP ? -1 : 1);

		if (controls.BACK)
		{
			__genocide = false;
			FlxG.sound.play(Paths.sound("cancelMenu"));
			if (onPlayState)
			{
				backend.StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(PlayState.new);
				FlxG.sound.music.volume = 0;
			}
			else
				MusicBeatState.switchState(states.MainMenuState.new);
		}
		else if (controls.ACCEPT)
		{
			final option = menuOptions[curSelected];
			__genocide = option != "Adjust Delay and Combo";
			openSelectedSubstate(option);
		}
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuOptions.length-1);

		var bullShit = 0;
		for (item in grpOptions.members)
		{
			item.targetY = bullShit++ - curSelected;

			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
			}
		}
		FlxG.sound.play(Paths.sound("scrollMenu"));
	}

	override function destroy()
	{
		grpOptions = null;
		selectorLeft = null;
		selectorRight = null;
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}