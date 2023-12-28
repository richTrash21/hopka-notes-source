package states;

import haxe.Json;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxSpriteGroup;
import flixel.addons.transition.FlxTransitionableState;
import shaders.ColorSwap;

@:structInit
class TitleData
{
	public var titlex:Float = -150;
	public var titley:Float = -100;
	public var startx:Float = 100;
	public var starty:Float = 576;
	public var gfx:Float = 512;
	public var gfy:Float = 40;
	public var backgroundSprite:String = '';
	public var bpm:Float = 102;
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

	var titleJson:TitleData;

	// whether the "press enter to begin" sprite is the old atlas or the new atlas
	var newTitle:Bool;

	final titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	final titleTextAlphas:Array<Float> = [1, .64];

	var titleTextTimer:Float;

	var randomPhrase:Array<String> = [];

	var textGroup:FlxSpriteGroup;
	var colourSwap:ColorSwap = null;

	override function create():Void
	{
		Paths.clearStoredMemory();
		FlxTransitionableState.skipNextTransOut = false;
		persistentUpdate = true;

		super.create();
		
		final balls = Json.parse(Paths.getTextFromFile('images/gfDanceTitle.json'));

		titleJson = {
			titlex: balls.titlex,
			titley: balls.titley,
			startx: balls.startx,
			starty: balls.starty,
			gfx: balls.gfx,
			gfy: balls.gfy,
			backgroundSprite: balls.backgroundSprite,
			bpm: balls.bpm,
		}

		Conductor.bpm = titleJson.bpm;

		if (titleJson.backgroundSprite != null && titleJson.backgroundSprite.length > 0 && titleJson.backgroundSprite != "none")
		{
			final bg:ExtendedSprite = new ExtendedSprite(0, 0, titleJson.backgroundSprite);
			bg.active = false;
			add(bg);
		}

		if (ClientPrefs.data.shaders) colourSwap = new ColorSwap();

		gf = new FlxSprite(titleJson.gfx, titleJson.gfy);
		gf.antialiasing = ClientPrefs.data.antialiasing;

		gf.frames = Paths.getSparrowAtlas('gfDanceTitle');
		gf.animation.addByIndices('left', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		gf.animation.addByIndices('right', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);

		gf.animation.play('right');
		gf.alpha = 0.0001;
		add(gf);

		logo = new FlxSprite(titleJson.titlex, titleJson.titley);
		logo.frames = Paths.getSparrowAtlas('logoBumpin');
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logo.animation.play('bump');
		logo.alpha = 0.0001;
		add(logo);

		if (colourSwap != null)
		{
			gf.shader = colourSwap.shader;
			logo.shader = colourSwap.shader;
		}

		titleText = new FlxSprite(titleJson.startx, titleJson.starty);
		titleText.visible = false;
		titleText.frames = Paths.getSparrowAtlas('titleEnter');

		final animFrames:Array<FlxFrame> = [];
		@:privateAccess
		{
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (animFrames.length > 0)
		{
			newTitle = true;
			
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			newTitle = false;
			
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		
		titleText.active = false;
		titleText.animation.play('idle');
		add(titleText);

		textGroup = new FlxSpriteGroup();
		add(textGroup);

		randomPhrase = FlxG.random.getObject(getIntroTextShit());

		if (!skippedIntro)
		{
			add(ngSpr = new FlxSprite(0, FlxG.height * 0.52, Paths.image('newgrounds_logo')));
			ngSpr.visible = false;
			ngSpr.active = false;
			ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
			ngSpr.updateHitbox();
			ngSpr.screenCenter(X);
			ngSpr.antialiasing = ClientPrefs.data.antialiasing;
			
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			FlxG.sound.music.fadeIn(4, 0, 0.7);
		}
		else skipIntro();

		Paths.clearUnusedMemory();
	}

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		final firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt', Paths.getPreloadPath());
		#else
		final fullText:String = Assets.getText(Paths.txt('introText'));
		final firstArray:Array<String> = fullText.split('\n');
		#end
		final swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray) swagGoodArray.push(i.split('--'));
		return swagGoodArray;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music != null) Conductor.songPosition = FlxG.sound.music.time;

		if (controls.ACCEPT)
		{
			if (skippedIntro)
			{
				if (!pressedEnter)
				{
					pressedEnter = true;

					if (ClientPrefs.data.flashing) titleText.active = true;
					titleText.animation.play('press');
					titleText.color = FlxColor.WHITE;
					titleText.alpha = 1;

					FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
					FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

					new FlxTimer().start(1, function(okFlixel:FlxTimer)
					{
						FlxTransitionableState.skipNextTransIn = false;
						MusicBeatState.switchState(new MainMenuState());
					});
				}
			} else skipIntro();
		}

		if (newTitle && !pressedEnter)
		{
			titleTextTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTextTimer > 2) titleTextTimer -= 2;

			var timer:Float = titleTextTimer;
			if (timer >= 1) timer = (-timer) + 2;
				
			timer = FlxEase.quadInOut(timer);
				
			titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
			titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
		}

		if (colourSwap != null)
		{
			if (controls.UI_LEFT)	colourSwap.hue -= elapsed * 0.1;
			if (controls.UI_RIGHT)	colourSwap.hue += elapsed * 0.1;
		}
	}

	override function beatHit():Void
	{
		gf.animation.play(FlxMath.isEven(curBeat) ? 'left' : 'right', true);
		logo.animation.play('bump', true);

		if (!skippedIntro)
		{
			switch (curBeat)
			{
				case 1:   createText(['ninjamuffin99', 'PhantomArcade', 'Kawai Sprite', 'evilsk8er']);
				case 3:   addMoreText('present');
				case 4:   deleteText();
				case 5:   createText(['In association', 'with'], -40);
				case 7:   addMoreText('Newgrounds', -40);
				case 8:   deleteText();
				case 9:   createText([randomPhrase[0]]);
				case 11:  addMoreText(randomPhrase[1]);
				case 12:  deleteText();
				case 13:  addMoreText('Friday');
				case 14:  addMoreText('Night');
				case 15:  addMoreText('Funkin');
				case 16:  skipIntro();
			}
			ngSpr.visible = (curBeat == 7);
	  }
  }

	function skipIntro()
	{
		FlxG.camera.flash(FlxColor.WHITE, 2);
		skippedIntro = true;

		gf.alpha = 1;
		logo.alpha = 1;
		titleText.visible = true;
		if (ngSpr != null) ngSpr.destroy();

		deleteText();
	}

	function createText(textArray:Array<String>, ?offset:Float = 0)
	{
		if (textGroup != null)
		{
			for (i in 0...textArray.length)
			{
				final txt:Alphabet = new Alphabet(0, 0, textArray[i], true);
				txt.screenCenter(X);
				txt.y += (i * 60) + 200 + offset;
				textGroup.add(txt);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if (textGroup != null)
		{
			final txt:Alphabet = new Alphabet(0, 0, text, true);
			txt.screenCenter(X);
			txt.y += (textGroup.length * 60) + 200 + offset;
			textGroup.add(txt);
		}
	}

	inline function deleteText() while (textGroup.members.length > 0) textGroup.remove(textGroup.members[0], true);
}