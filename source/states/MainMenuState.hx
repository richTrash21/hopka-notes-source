package states;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.typeLimit.NextState;
import flixel.effects.FlxFlicker;

import options.OptionsState;

class MainMenuState extends MusicBeatState
{
	public static final psychEngineVersion = "0.7.1" #if debug + " [DEBUG]" #end; // This is also used for Discord RPC
	public static var curSelected = 0;

	@:allow(states.StoryMenuState)
	@:allow(states.FreeplayState)
	static var pizzaTime = false;
	@:allow(states.DoiseRoomLMAO)
	static var doiseTrans = false;

	static final optionShit:Array<MainMenuOption> = [
		["story_mode",	StoryMenuState.new],
		["freeplay",	FreeplayState.new],
		// #if ACHIEVEMENTS_ALLOWED
		["awards",		AchievementsMenuState.new],
		// #end
		["credits",		CreditsState.new],
		// ["donate"], // will be deleted prob idk
		["options",		OptionsState.new, true]
	];

	var menuItems:FlxTypedGroup<FlxSprite>;
	var magenta:FlxSprite;

	override function create()
	{
		#if (flixel < "6.0.0")
		// ну привет редар :) - rich
		final normalCamera = new objects.GameCamera(true);
		normalCamera.zoomDecay = 2.375;
		FlxG.cameras.reset(normalCamera);
		#end

		if (doiseTrans)
		{
			FlxG.fullscreen = false;
			doiseTrans = false;
		}

		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0);

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		Mods.loadTopMod();
		#end

		#if hxdiscord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		// transIn = FlxTransitionableState.defaultTransIn;
		// transOut = FlxTransitionableState.defaultTransOut;
		persistentUpdate = true;

		final yScroll = Math.max(0.2 - (0.05 * (optionShit.length - 4)), 0.1);
		final bg = new FlxSprite(Paths.image("menuBG"));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(bg.width * 1.175);
		bg.updateHitbox();
		bg.active = false;
		add(bg.screenCenter());

		magenta = new FlxSprite(0, 0, Paths.image("menuDesat"));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(magenta.width * 1.175);
		magenta.updateHitbox();
		magenta.color = 0xFFfd719b;
		magenta.active = magenta.visible = false;
		add(magenta.screenCenter());

		final grid = new flixel.addons.display.FlxBackdrop(flixel.addons.display.FlxGridOverlay.createGrid(1, 1, 2, 2, true, 0x33FFFFFF, 0x0));
		grid.scale.scale(80);
		grid.scrollFactor.set(0, yScroll);
		grid.velocity.set(40, 40);
		add(grid);
		
		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		final itemScrollY = optionShit.length < 6 ? 0 : (optionShit.length - 4) * 0.135;
		final offset = (optionShit.length > 4 ? 108 : 22 * optionShit.length) - (Math.max(optionShit.length, 4) - 4) * 80;
		final mult = optionShit.length > 4 ? 140 : optionShit.length * 36;
		for (i in 0...optionShit.length)
		{
			final name = optionShit[i].name;
			final menuItem = new FlxSprite(0, (i * mult) + offset);
			menuItem.antialiasing = ClientPrefs.data.antialiasing;
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
			menuItem.animation.addByPrefix("idle",     '$name basic', 24);
			menuItem.animation.addByPrefix("selected", '$name white', 24);
			menuItem.animation.play("idle");
			menuItem.ID = i;
			menuItems.add(menuItem).screenCenter(X);
			menuItem.scrollFactor.set(0, itemScrollY);
		}

		final psychVersion = new FlxText(12, FlxG.height - 44, 0, "Commit #" + FlxG.stage.application.meta.get("build"), 16);
		psychVersion.active = false;
		psychVersion.scrollFactor.set();
		psychVersion.font = Paths.font("vcr.ttf");
		add(psychVersion.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK));

		/*final fnfVersion = new FlxText(12, FlxG.height - 44, 0, "Friday Night Funkin v" + FlxG.stage.application.meta.get("version"), 16);
		fnfVersion.active = false;
		fnfVersion.scrollFactor.set();
		fnfVersion.font = Paths.font("vcr.ttf");
		add(fnfVersion.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK));*/

		final doiseTrap = new FlxText(12, FlxG.height - 24, 0, "NOTE: Press F1 for the funny!" , 16);
		doiseTrap.active = false;
		doiseTrap.scrollFactor.set();
		doiseTrap.font = Paths.font("vcr.ttf");
		add(doiseTrap.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK));

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		final leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			backend.Achievements.unlock("friday_night_play");

		#if MODS_ALLOWED
		backend.Achievements.reloadList();
		#end
		#end

		// TABULATION TEST
		// add(new Alphabet(10, 40, "TABULATION TEST\n\tTEST\n\t\tTEST\n\t\tTE\tST\nT\tE\tS\tT\n\tUR\t\tMOM\n\t>:3", true));

		#if desktop
		__clearTxt = new FlxText("MEMORY CLEARED!", 24);
		__clearTxt.scrollFactor.set();
		__clearTxt.font = "VCR OSD Mono";
		__clearTxt.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1.25);
		__clearTxt.setPosition(FlxG.width - __clearTxt.width - 5, FlxG.height - __clearTxt.height - 5);
		add(__clearTxt);
		__clearTxt.alpha = 0;
		#end

		super.create();
		FlxG.camera.followLerp = 0.15;
	}

	var selectedSomethin:Bool = false;
	#if desktop
	var __clearTxt:FlxText;
	var __tween:FlxTween;
	#end

	@:access(flixel.tweens.FlxTween.finish)
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
			if (FreeplayState.vocals?.playing)
				FreeplayState.vocals.volume = FlxG.sound.music.volume;
		}
		Conductor.songPosition = FlxG.sound.music.time;

		if (!selectedSomethin)
		{
			final UP = controls.UI_UP_P;
			if (UP || controls.UI_DOWN_P)
				changeItem(UP ? -1 : 1);

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound("cancelMenu"));
				MusicBeatState.switchState(TitleState.new);
			}

			if (controls.ACCEPT)
			{
				final curOption = optionShit[curSelected];
				if (curOption.name == "donate")
					CoolUtil.browserLoad("https://t.me/hopka_notes");
				else
				{
					selectedSomethin = true;
					FlxG.sound.play(Paths.sound("confirmMenu"));
					if (ClientPrefs.data.flashing)
						FlxFlicker.flicker(magenta, 1.1, 0.15, false);

					if (curOption.name == "options")
					{
						OptionsState.onPlayState = false;
						if (PlayState.SONG != null)
							PlayState.SONG.arrowSkin = PlayState.SONG.splashSkin = null;
					}
					menuItems.forEach((spr) ->
					{
						if (curSelected == spr.ID)
							FlxFlicker.flicker(spr, 1, 0.06, false, false, (_) ->
							{
								if (curOption.preload)
									LoadingState.loadAndSwitchState(curOption.state);
								else
									MusicBeatState.switchState(curOption.state);
							});
						else
							FlxTween.num(1, 0, 0.4, {ease: FlxEase.quadOut}, (a) -> spr.alpha = a);
					});
				}
			}
			#if desktop
			#if !RELESE_BUILD_FR
			else if (controls.justPressed("debug_1"))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(states.editors.MasterEditorMenu.new);
			}
			else if (FlxG.keys.justPressed.SIX) // intro testing
			{
				selectedSomethin = true;
				FlxTransitionableState.skipNextTransIn = true;
				MusicBeatState.switchState(Init.new);
				FlxG.sound.music.volume = 0;
			}
			else if (FlxG.keys.justPressed.EIGHT) // pc state testing
			{
				selectedSomethin = true;
				MusicBeatState.switchState(PCState.new);
			}
			else if (FlxG.keys.justPressed.NINE) // video testing
			{
				selectedSomethin = true;
				MusicBeatState.switchState(TestVideoState.new);
			}
			#end
			else if (controls.justPressed("reset")) // garbage begone!!!
			{
				if (__tween != null)
					__tween.finish();

				__tween = FlxTween.num(1, 0, 0.4, {startDelay: 0.8, onComplete: (_) -> __tween = null}, (a) -> __clearTxt.alpha = a);
				FlxG.sound.play(Paths.sound("cancelMenu"));

				final curMem = Main.fpsVar.memoryMegas;
				Paths.clearUnusedMemory();
				cpp.vm.Gc.run(true);
				final memDelta = FlxMath.maxInt(curMem - Main.fpsVar.memoryMegas, 0);
				trace("cleared garbage lmao [" + (memDelta == 0 ? "actually not" : flixel.util.FlxStringUtil.formatBytes(memDelta)) + "]");
			}
			#end

			// THE DOISE ROOM!!!!!
			if (FlxG.keys.justPressed.F1)
			{
				selectedSomethin = true;
				pizzaTime = false;
				FlxG.sound.music.stop();
				final snd = FlxG.sound.play(Paths.sound("cancelMenu"));
				snd.onComplete = () -> snd.persist = false;
				snd.persist = true;
	
				FlxG.camera.fade(FlxColor.BLACK, 0);
				FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;
				new FlxTimer().start((_) -> MusicBeatState.switchState(DoiseRoomLMAO.new));
			}
		}

		final N = FlxG.keys.justPressed.N;
		if (N || FlxG.keys.justPressed.P) // just don't ask, i was bored lmao - richTrash21
		{
			if (pizzaTime)
			{
				FlxG.sound.playMusic(Paths.music("freakyMenu"));
				FlxG.camera.zoom = 1;
				Conductor.bpm = 102;
			}
			else
			{
				if (N) // WORLD WIDE NOISE!!
				{
					// this is a hell of a name, good job on the song tho
					FlxG.sound.playMusic(Paths.music("World_Wide_Noise_v6_yo_how_many_times_am_i_just_gonna_keep_changing_the_guitar_slightly_at_the_end"));
					FlxG.sound.music.endTime = (60 / (Conductor.bpm = 167) * 4000) * 96;
				}
				else // ITS PIZZA TIME!!
				{
					FlxG.sound.playMusic(Paths.music("mu_pizzatime"));
					final barMS = 60 / (Conductor.bpm = 180) * 4000;
					FlxG.sound.music.loopTime = barMS * 36;
					FlxG.sound.music.endTime = barMS * 120;
				}
				FlxG.camera.zoom += 0.02;
			}
			pizzaTime = !pizzaTime;
		}
		super.update(elapsed);
	}

	override function beatHit()
	{
		if (pizzaTime)
			FlxG.camera.zoom += 0.02;
	}

	function changeItem(huh = 0)
	{
		if (huh != 0)
			FlxG.sound.play(Paths.sound("scrollMenu"));

		var spr = menuItems.members[curSelected];
		spr.animation.play("idle");
		spr.centerOffsets();
	
		curSelected = FlxMath.wrap(curSelected + huh, 0, menuItems.length-1);

		spr = menuItems.members[curSelected];
		spr.animation.play("selected");
		spr.centerOffsets();
		FlxG.camera.target = spr;
	}
}

abstract MainMenuOption(__OptionType) from __OptionType to __OptionType
{
	public var name(get, never):String;
	public var state(get, never):NextState;
	public var preload(get, never):Bool;

	@:noCompletion inline function get_name():String      return this[0];
	@:noCompletion inline function get_state():NextState  return this[1];
	@:noCompletion inline function get_preload():Bool     return this[2];
}

@:noCompletion private typedef __OptionType = Array<Dynamic>; // had to use dynamic wahhh 😭😭
