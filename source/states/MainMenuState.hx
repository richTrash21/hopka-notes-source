package states;

import flixel.addons.display.FlxBackdrop;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;

import options.OptionsState;

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

class MainMenuState extends MusicBeatState
{
	public static final psychEngineVersion:String = '0.7.1' #if debug + ' [DEBUG]' #end; //This is also used for Discord RPC
	public static var curSelected:Int = 0;
	static final optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if (MODS_ALLOWED && debug) 'mods', #end //shouldn't be included in release build lmao
		'credits',
		#if !switch 'donate', #end
		'options'
	];

	var menuItems:FlxTypedGroup<FlxSprite>;
	#if ACHIEVEMENTS_ALLOWED
	private var camGame:FlxCamera;
	private var camAchievement:FlxCamera;
	#end

	var magenta:FlxSprite;

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		#if ACHIEVEMENTS_ALLOWED
		camGame = new FlxCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		#end

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		persistentUpdate = persistentDraw = true;

		final yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);

		final bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.active = false;
		add(bg);

		magenta = new FlxSprite(0, 0, Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		magenta.active = false;
		add(magenta);

		final grid:FlxBackdrop = new FlxBackdrop(flixel.addons.display.FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.scrollFactor.set(0, yScroll);
		grid.velocity.set(40, 40);
		add(grid);
		
		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		final offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
		for (i in 0...optionShit.length)
		{
			final menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);
			menuItem.antialiasing = ClientPrefs.data.antialiasing;
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
			menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItems.add(menuItem);
			menuItem.scrollFactor.set(0, optionShit.length < 6 ? 0 : (optionShit.length - 4) * 0.135);
		}

		FlxG.camera.follow(menuItems.members[0], null, 0);

		final psychVersion:FlxText = new FlxText(12, FlxG.height - 44, 0, 'Psych Engine v$psychEngineVersion', 16);
		psychVersion.active = false;
		psychVersion.scrollFactor.set();
		psychVersion.borderStyle = FlxTextBorderStyle.OUTLINE;
		psychVersion.borderColor = FlxColor.BLACK;
		psychVersion.font = Paths.font('vcr.ttf');
		add(psychVersion);

		final fnfVersion:FlxText = new FlxText(12, FlxG.height - 24, 0, 'Friday Night Funkin v${lime.app.Application.current.meta.get('version')}', 16);
		fnfVersion.active = false;
		fnfVersion.scrollFactor.set();
		fnfVersion.borderStyle = FlxTextBorderStyle.OUTLINE;
		fnfVersion.borderColor = FlxColor.BLACK;
		fnfVersion.font = Paths.font('vcr.ttf');
		add(fnfVersion);

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		Achievements.loadAchievements();
		final leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18) {
			final achieveID:Int = Achievements.getAchievementIndex('friday_night_play');
			if(!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2])) { //It's a friday night. WEEEEEEEEEEEEEEEEEE
				Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
				giveAchievement();
				ClientPrefs.saveSettings();
			}
		}
		#end

		super.create();
	}

	#if ACHIEVEMENTS_ALLOWED
	// Unlocks "Freaky on a Friday Night" achievement
	function giveAchievement() {
		add(new objects.AchievementPopup('friday_night_play', camAchievement));
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		trace('Giving achievement "friday_night_play"');
	}
	#end

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
			if(FreeplayState.vocals != null) FreeplayState.vocals.volume += 0.5 * elapsed;
		}
		FlxG.camera.followLerp = elapsed * 9 #if (flixel < "5.4.0") / #else * #end (FlxG.updateFramerate / 60);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P || controls.UI_DOWN_P)
				changeItem(controls.UI_UP_P ? -1 : 1);

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				if (optionShit[curSelected] == 'donate') CoolUtil.browserLoad('https://t.me/hopka_notes');
				else
				{
					selectedSomethin = true;
					FlxG.sound.play(Paths.sound('confirmMenu'));
					if(ClientPrefs.data.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false);

					menuItems.forEach(function(spr:FlxSprite)
					{
						if (curSelected == spr.ID)
						{
							FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
								switchShit(optionShit[curSelected]));
							return;
						}
						FlxTween.num(1, 0, 0.4, {ease: FlxEase.quadOut, onComplete: function(_) spr.destroy()}, function(value:Float) spr.alpha = value);
					});
				}
			}
			#if desktop
			#if !RELESE_BUILD_FR
			else if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new states.editors.MasterEditorMenu());
			}
			#end
			else if (controls.justPressed('reset')) // garbage begone!!!
			{
				var massage:FlxText = new FlxText(0, 0, 0, "MEMORY CLEARED!"); // I KNOW THAT I MISSPELLED IT!!!!
				massage.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				massage.setPosition(FlxG.width - massage.width - 5, FlxG.height - massage.height - 5);
				massage.scrollFactor.set();
				massage.borderSize = 1.2;
				add(massage);
				FlxTween.num(1, 0, 0.4, {startDelay: 0.8, onComplete: function(_) massage.destroy()}, function(value:Float) massage.alpha = value);

				FlxG.sound.play(Paths.sound('cancelMenu'));
				Paths.clearUnusedMemory();
				cpp.vm.Gc.run(true);
				trace('cleared garbage lmao');
			}
			#end
		}
		super.update(elapsed);
	}

	function changeItem(huh:Int = 0)
	{
		if (huh != 0) FlxG.sound.play(Paths.sound('scrollMenu'));
		curSelected = FlxMath.wrap(curSelected + huh, 0, menuItems.length-1);

		menuItems.forEach(function(spr:FlxSprite)
		{
			if (spr.ID == curSelected)
			{
				FlxG.camera.follow(spr, null, 0);
				spr.animation.play('selected');
				spr.centerOffsets();
				return;
			}
			spr.animation.play('idle');
			spr.updateHitbox();
		});
	}
	
	function switchShit(name:String)
		switch (name) {
			case 'story_mode':
				MusicBeatState.switchState(new StoryMenuState());
			case 'freeplay':
				MusicBeatState.switchState(new FreeplayState());
			#if MODS_ALLOWED
			case 'mods':
				MusicBeatState.switchState(new ModsMenuState());
			#end
			case 'credits':
				MusicBeatState.switchState(new CreditsState());
			case 'options':
				LoadingState.loadAndSwitchState(new OptionsState());
				OptionsState.onPlayState = false;
				if (PlayState.SONG != null)
				{
					PlayState.SONG.arrowSkin = null;
					PlayState.SONG.splashSkin = null;
				}
		}
}
