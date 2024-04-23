package states.editors;

#if !RELESE_BUILD_FR
import backend.WeekData;

import objects.Character;

import states.MainMenuState;
import states.FreeplayState;

class MasterEditorMenu extends MusicBeatState
{
	static var options:Array<states.MainMenuState.MainMenuOption> = [
		["Chart Editor",				ChartingState.new, true],
		["Character Editor",			()->new CharacterEditorState(Character.DEFAULT_CHARACTER, false), true],
		["Week Editor",					()->new WeekEditorState()],
		["Menu Character Editor",		MenuCharacterEditorState.new],
		["Dialogue Editor",				DialogueEditorState.new, true],
		["Dialogue Portrait Editor",	DialogueCharacterEditorState.new, true],
		["Note Splash Debug",			NoteSplashDebugState.new, true],
		["Mods Menu",					ModsMenuState.new] // do not ask
	];
	static var curSelected = 0;
	static var curDirectory = 0;

	var grpTexts:FlxTypedGroup<Alphabet>;
	var directories:Array<String> = [null];
	var directoryTxt:FlxText;

	override function create()
	{
		persistentUpdate = true;

		FlxG.camera.bgColor = FlxColor.BLACK;
		#if hxdiscord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image("menuDesat"));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		for (i in 0...options.length)
		{
			final leText = new Alphabet(90, 320, options[i].name, true);
			leText.isMenuItem = true;
			leText.targetY = i;
			grpTexts.add(leText);
			leText.snapToPosition();
		}
		
		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0x99000000);
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, "", 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		
		for (folder in Mods.getModDirectories())
			directories.push(folder);

		final found = directories.indexOf(Mods.currentModDirectory);
		if (found != -1)
			curDirectory = found;
		changeDirectory();
		#end
		changeSelection();

		// FlxG.mouse.visible = false;
		super.create();
	}

	var selectedSomething = false;
	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P)    changeSelection(-1);
		if (controls.UI_DOWN_P)  changeSelection(1);
		#if MODS_ALLOWED
		if (controls.UI_LEFT_P)  changeDirectory(-1);
		if (controls.UI_RIGHT_P) changeDirectory(1);
		#end

		if (controls.BACK)
			FlxG.switchState(MainMenuState.new);

		if (controls.ACCEPT && !selectedSomething)
		{
			selectedSomething = true;
			final curOption = options[curSelected];
			if (curOption.preload)
				LoadingState.loadAndSwitchState(curOption.state);
			else
				FlxG.switchState(curOption.state);
			if (curOption.name != "Mods Menu")
				FlxG.sound.music.volume = 0;
			#if PRELOAD_ALL
			FreeplayState.stopVocals();
			#end
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		curSelected = FlxMath.wrap(curSelected + change, 0, options.length-1);

		var bullShit = 0;
		for (item in grpTexts.members)
		{
			item.targetY = bullShit++ - curSelected;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		if(change != 0)
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		curDirectory = FlxMath.wrap(curDirectory + change, 0, directories.length-1);
	
		WeekData.setDirectoryFromWeek();
		final txt = if (directories[curDirectory] == null || directories[curDirectory].length < 1)
			"No Mod Directory Loaded";
		else
			directoryTxt.text = "Loaded Mod Directory: " + (Mods.currentModDirectory = directories[curDirectory]);

		directoryTxt.text = "< " + txt.toUpperCase() + " >";
	}
	#end
}
#end