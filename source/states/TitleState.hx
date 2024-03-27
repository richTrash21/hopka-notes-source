package states;

import flixel.addons.transition.FlxTransitionableState;
import shaders.ColorSwap;

typedef TitleData = {
	titlex:Float,
	titley:Float,
	startx:Float,
	starty:Float,
	gfx:Float,
	gfy:Float,
	backgroundSprite:String,
	bpm:Float
}

// REWRITTEN BY Rudyrue (https://github.com/ShadowMario/FNF-PsychEngine/pull/13695)
class TitleState extends MusicBeatState
{
	public static var skippedIntro:Bool = false;

	var pressedEnter:Bool = false;

	var gf:FlxSprite;
	var logo:FlxSprite;
	var titleText:FlxSprite;
	var ngSpr:FlxSprite;

	// whether the "press enter to begin" sprite is the old atlas or the new atlas
	var newTitle:Bool;
	var titleTextTimer:Float;
	var randomPhrase:Array<String> = [];

	var textGroup:FlxTypedGroup<Alphabet>;
	var colorSwap:ColorSwap;

	override function create():Void
	{
		Paths.clearStoredMemory();
		FlxTransitionableState.skipNextTransOut = true;
		persistentUpdate = true;

		super.create();

		final titleJson:TitleData = cast haxe.Json.parse(Paths.getTextFromFile("images/gfDanceTitle.json"));

		if (!skippedIntro)
			Conductor.bpm = titleJson.bpm;

		if (titleJson.backgroundSprite != null && titleJson.backgroundSprite.length > 0 && titleJson.backgroundSprite != "none")
			add(new ExtendedSprite(titleJson.backgroundSprite)).active = false;

		if (ClientPrefs.data.shaders)
			colorSwap = new ColorSwap();

		gf = new FlxSprite(titleJson.gfx, titleJson.gfy);
		gf.antialiasing = ClientPrefs.data.antialiasing;

		gf.frames = Paths.getSparrowAtlas("gfDanceTitle");
		gf.animation.addByIndices("left", "gfDance", [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		gf.animation.addByIndices("right", "gfDance", [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);

		gf.animation.play("right");
		add(gf);
		gf.precache();
		gf.visible = false;

		logo = new FlxSprite(titleJson.titlex, titleJson.titley);
		logo.frames = Paths.getSparrowAtlas("logoBumpin");
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.animation.addByPrefix("bump", "logo bumpin", 24, false);
		logo.animation.play("bump");
		add(logo);
		logo.precache();
		logo.visible = false;

		if (colorSwap != null)
			gf.shader = logo.shader = colorSwap.shader;

		titleText = new FlxSprite(titleJson.startx, titleJson.starty);
		titleText.frames = Paths.getSparrowAtlas("titleEnter");

		if ((newTitle = (titleText.frames.exists("ENTER IDLE0000") || titleText.frames.exists("ENTER FREEZE0000"))))
		{
			titleText.animation.addByPrefix("idle", "ENTER IDLE", 24);
			titleText.animation.addByPrefix("press", "ENTER " + (ClientPrefs.data.flashing ? "PRESSED" : "FREEZE"), 24);
		}
		else
		{
			titleText.animation.addByPrefix("idle", "Press Enter to Begin", 24);
			titleText.animation.addByPrefix("press", "ENTER PRESSED", 24);
		}

		titleText.animation.play("idle");
		add(titleText);
		titleText.precache();
		titleText.visible = titleText.active = false;

		textGroup = new FlxTypedGroup();
		add(textGroup);

		randomPhrase = FlxG.random.getObject(getIntroTextShit());

		if (!skippedIntro)
		{
			add(ngSpr = new FlxSprite(0, FlxG.height * 0.52, Paths.image("newgrounds_logo")));
			ngSpr.antialiasing = ClientPrefs.data.antialiasing;
			ngSpr.setGraphicSize(ngSpr.width * 0.8);
			ngSpr.updateHitbox();
			ngSpr.screenCenter(X);
			ngSpr.precache();
			ngSpr.visible = ngSpr.active = false;

			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0);
			FlxG.sound.music.fadeIn(4, 0, 0.7);
		}
		else
			skipIntro();

		Paths.clearUnusedMemory();
	}

	inline function getIntroTextShit():Array<Array<String>>
	{
		var firstArray:Array<String>;
		#if MODS_ALLOWED
		firstArray = Mods.mergeAllTextsNamed("data/introText.txt", Paths.getPreloadPath());
		#else
		firstArray = Assets.getText(Paths.txt("introText")).split("\n");
		#end
		return [for (i in firstArray) i.split("--")];
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		if (controls.ACCEPT)
		{
			if (skippedIntro)
			{
				if (!pressedEnter)
				{
					pressedEnter = true;

					if (ClientPrefs.data.flashing)
						titleText.active = true;
					titleText.animation.play("press");
					titleText.color = FlxColor.WHITE;
					titleText.alpha = 1;

					FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
					FlxG.sound.play(Paths.sound("confirmMenu"), 0.7);

					new FlxTimer().start(1, (_) ->
					{
						FlxTransitionableState.skipNextTransIn = false;
						MusicBeatState.switchState(MainMenuState.new);
					});
				}
			}
			else
				skipIntro();
		}

		if (newTitle && !pressedEnter)
		{
			if ((titleTextTimer += elapsed) > 2)
				titleTextTimer -= 2;
				
			final timer = FlxEase.quadInOut(titleTextTimer >= 1 ? (-titleTextTimer) + 2 : titleTextTimer);
			titleText.color = FlxColor.interpolate(0xFF33FFFF, 0xFF3333CC, timer);
			titleText.alpha = FlxMath.lerp(1, .64, timer);
		}

		if (colorSwap != null)
		{
			if (controls.UI_LEFT)
				colorSwap.hue -= elapsed * 0.1;
			else if (controls.UI_RIGHT)
				colorSwap.hue += elapsed * 0.1;
		}
	}

	override function beatHit():Void
	{
		gf.animation.play(FlxMath.isEven(curBeat) ? "left" : "right", true);
		logo.animation.play("bump", true);

		if (!skippedIntro)
		{
			ngSpr.visible = curBeat == 7;
			switch (curBeat)
			{
				case 1:   createText(["ninjamuffin99", "PhantomArcade", "Kawai Sprite", "evilsk8er"]);
				case 3:   addMoreText("present");
				case 4:   deleteText();
				case 5:   createText(["In association", "with"], -40);
				case 7:   addMoreText("Newgrounds", -40);
				case 8:   deleteText();
				case 9:   createText([randomPhrase[0]]);
				case 11:  addMoreText(randomPhrase[1]);
				case 12:  deleteText();
				case 13:  addMoreText("Friday");
				case 14:  addMoreText("Night");
				case 15:  addMoreText("Funkin");
				case 16:  skipIntro();
			}
	  }
  }

	function skipIntro()
	{
		FlxG.camera.flash(FlxColor.WHITE, 2);
		gf.visible = logo.visible = titleText.visible = skippedIntro = true;
		ngSpr = flixel.util.FlxDestroyUtil.destroy(ngSpr);
		deleteText();
	}

	inline function createText(textArray:Array<String>, ?offset = 0.)
	{
		for (i in 0...textArray.length)
			addMoreText(textArray[i], offset, i);
	}

	inline function addMoreText(text:String, ?offset = 0., ?i:Int)
	{
		textGroup.add(new Alphabet(0, ((i ?? textGroup.length) * 60) + 200 + offset, text, true)).screenCenter(X);
	}
	
	inline function deleteText()
	{
		while (textGroup.members.length > 0)
			textGroup.remove(textGroup.members[0], true).destroy();
	}
}