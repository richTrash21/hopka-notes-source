package states;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.typeLimit.NextState;
import flixel.effects.FlxFlicker;

import options.OptionsState;

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

class MainMenuState extends MusicBeatState
{
	public static final psychEngineVersion = "0.7.1" #if debug + " [DEBUG]" #end; // This is also used for Discord RPC
	public static var curSelected = 0;

	@:allow(states.StoryMenuState)
	@:allow(states.FreeplayState)
	static var pizzaTime = false;

	static final optionShit:Array<MainMenuOption> = [
		["story_mode",	StoryMenuState.new],
		["freeplay",	FreeplayState.new],
		#if (MODS_ALLOWED && debug) // shouldn't be included in release build lmao
		["mods",		ModsMenuState.new],
		#end
		["credits",		CreditsState.new],
		["donate"], // will be deleted prob idk
		["options",		OptionsState.new, true]
	];

	var menuItems:FlxTypedGroup<FlxSprite>;
	var magenta:FlxSprite;

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		Mods.loadTopMod();
		#end

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		#if ACHIEVEMENTS_ALLOWED
		final camGame = new FlxCamera();
		final camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		#end

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;
		persistentUpdate = persistentDraw = true;

		final yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
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

		final grid = new flixel.addons.display.FlxBackdrop(flixel.addons.display.FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
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
		// FlxG.camera.target = menuItems.members[0];

		final psychVersion = new FlxText(12, FlxG.height - 44, 0, 'Psych Engine v$psychEngineVersion', 16);
		psychVersion.active = false;
		psychVersion.scrollFactor.set();
		psychVersion.font = Paths.font("vcr.ttf");
		add(psychVersion.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK));

		final fnfVersion = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin v" + lime.app.Application.current.meta.get("version"), 16);
		fnfVersion.active = false;
		fnfVersion.scrollFactor.set();
		fnfVersion.font = Paths.font("vcr.ttf");
		add(fnfVersion.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK));

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		Achievements.loadAchievements();
		final leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
		{
			final achieveID = Achievements.getAchievementIndex("friday_night_play");
			if (!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2])) //It's a friday night. WEEEEEEEEEEEEEEEEEE
			{
				Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
				add(new objects.AchievementPopup("friday_night_play", camAchievement));
				FlxG.sound.play(Paths.sound("confirmMenu"), 0.7);
				trace("Giving achievement \"friday_night_play\"");
				ClientPrefs.saveSettings();
			}
		}
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
			if (FreeplayState.vocals.playing)
				FreeplayState.vocals.volume = FlxG.sound.music.volume;
		}
		FlxG.camera.followLerp = elapsed * 9 * (FlxG.updateFramerate / 60);

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
		}

		if (pizzaTime)
			Conductor.songPosition = FlxG.sound.music.time;
		if (FlxG.camera.zoom != 1)
			FlxG.camera.zoom = FlxMath.lerp(1, FlxG.camera.zoom, Math.exp(-elapsed * 7.6));
		// if (FlxG.camera.angle != 0)
		//	FlxG.camera.angle = FlxMath.lerp(0, FlxG.camera.angle, Math.exp(-elapsed * 7.6));

		final P = FlxG.keys.justPressed.P;
		if (P || FlxG.keys.justPressed.N) // just don't ask, i was bored lmao - richTrash21
		{
			if (pizzaTime)
			{
				FlxG.sound.playMusic(Paths.music("freakyMenu"));
				FlxG.camera.zoom = 1;
				Conductor.bpm = 102;
			}
			else
			{
				if (P) // ITS PIZZA TIME!!
				{
					FlxG.sound.playMusic(Paths.music("mu_pizzatime"));
					final barMS = 60 / (Conductor.bpm = 180) * 4000;
					FlxG.sound.music.loopTime = barMS * 36;
					FlxG.sound.music.endTime = barMS * 120;
				}
				else // WORLD WIDE NOISE!!
				{
					// this is a hell of a name, good job on the song tho
					FlxG.sound.playMusic(Paths.music("World_Wide_Noise_v6_yo_how_many_times_am_i_just_gonna_keep_changing_the_guitar_slightly_at_the_end"));
					FlxG.sound.music.endTime = (60 / (Conductor.bpm = 167) * 4000) * 96;
				}
				FlxG.camera.zoom += 0.02;
			}
			pizzaTime = !pizzaTime;
		}
		super.update(elapsed);
	}

	// var __angleIn:Bool;
	override function beatHit()
	{
		if (pizzaTime)
		{
			FlxG.camera.zoom += 0.02;
			// FlxG.camera.angle += (__angleIn = !__angleIn) ? .5 : -.5;
		}
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

typedef __OptionType = Array<Dynamic>; // had to use dynamic wahhh 😭😭
