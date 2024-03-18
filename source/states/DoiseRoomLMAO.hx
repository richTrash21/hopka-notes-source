package states;

import flixel.input.keyboard.FlxKey;
import flixel.FlxSubState;
import flixel.addons.display.FlxBackdrop;

class DoiseRoomLMAO extends MusicBeatState
{
	override public function create()
	{
		MainMenuState.doiseTrans = true;
		TitleState.skippedIntro = true;

		// pt screen size: 960x540
		final sprScale = FlxG.width / 960;

		final bg = new FlxBackdrop(Paths.image("doiseRoom/Bg_doisebossBG4"));
		bg.velocity.set(30, 30);
		bg.scale.set(sprScale, sprScale);
		bg.updateHitbox();
		add(bg);
		// bg.pixelPerfectPosition = bg.pixelPerfectRender = true;

		final doiseMass = new FlxBackdrop();
		doiseMass.loadGraphic(Paths.image("doiseRoom/Bg_doisebossBG2"), true, 960, 540);
		doiseMass.animation.add("idle", [0, 1], 24);
		doiseMass.animation.play("idle");
		doiseMass.velocity.set(-60, -60);
		doiseMass.scale.set(sprScale, sprScale);
		doiseMass.updateHitbox();
		add(doiseMass);
		// doiseMass.pixelPerfectPosition = doiseMass.pixelPerfectRender = true;

		// looks like squidward lmao
		final doisey = new ExtendedSprite(0, 10, null, false);
		doisey.loadGraphic(Paths.image("doiseRoom/Bg_doisewalk_0"), true, 375, 325);
		doisey.animation.add("idle", [0, 1, 2], 10);
		doisey.animation.play("idle");
		doisey.boundBox = flixel.math.FlxRect.get(0, 0, FlxG.width, FlxG.height);
		doisey.onLeaveBounds = (s) -> doisey.x -= doisey.boundBox.width + doisey.width; // backdrop effect but it's not a backdrop lol
		doisey.scale.set(sprScale, sprScale);
		doisey.updateHitbox();
		doisey.velocity.x = 60;
		add(doisey);
		// doisey.pixelPerfectPosition = doisey.pixelPerfectRender = true;

		/*final doxxText = new FlxText(0, 560, 0, "Welcome to The Doise Room, " + Sys.getEnv("USERNAME") + "!", 32);
		doxxText.active = false;
		add(doxxText.setBorderStyle(OUTLINE, FlxColor.BLACK, 4).screenCenter(X));*/

		if (FlxG.save.data.doisedCount == null)
			FlxG.save.data.doisedCount = 1;
		else
			FlxG.save.data.doisedCount += 1;

		final doxx = Sys.getEnv("USERNAME");
		var txt = FlxG.save.data.isDoised ? 'Welcome back, $doxx!\nIt\'s your ' + formatNumber(FlxG.save.data.doisedCount) + " here!" : 'Welcome to The Doise Room, $doxx!';
		final doxxText = new Alphabet(txt);
		doxxText.forEachAlive((s) -> { s.antialiasing = false; s.pixelPerfectRender = true; });
		doxxText.setScale(0.6333);
		/*doxxText.alignment = CENTER;
		if (doxxText.rows > 1)
			doxxText.x = Math.abs(FlxG.width - doxxText.width) * 1.25;
		else*/
			doxxText.screenCenter(X);
		doxxText.y = 640 - doxxText.height;
		// trace("idk: " + (FlxG.width - doxxText.width) + " full: " + doxxText.x);
		add(doxxText);

		FlxG.fullscreen = true;
		FlxG.sound.playMusic(Paths.music("Pizza_Tower_OST_-_Doise_At_the_Door(1)"));
		FlxG.sound.music.time = (60 / (Conductor.bpm = 132) * 1000) * 15;

		persistentUpdate = true;
		FlxG.save.data.isDoised = true;
		FlxG.save.flush();
		super.create();
		trace("you shouldn't have done that...");
	}

	inline static function formatNumber(n:Int):String
	{
		return n + switch (n > 20 ? n % 10 : n)
		{
			case 1: "st";
			case 2: "nd";
			case 3: "rd";
			default: "th";
		}
	}

	static final escapeCode:Array<FlxKey> = [D, O, I, S, E];
	final escapeInput = new Array<Int>();
	#if desktop
	var updateRpc = true;
	var rpcTimer = 0.;
	#end

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		#if desktop
		if (updateRpc)
			if ((rpcTimer += elapsed) > 1)
			{
				DiscordClient.changePresence("???");
				updateRpc = false;
			}
		#end

		if (FlxG.keys.justPressed.ANY && subState == null)
		{
			final firstKey:FlxKey = FlxG.keys.firstJustPressed();
			if (firstKey == NONE || firstKey.toString().length != 1)
				return;

			escapeInput.push(firstKey);
			/*while (escapeInput.length > escapeCode.length)
				escapeInput.shift();*/

			if (escapeInput.length == escapeCode.length)
			{
				var matched = false;
				for (i => key in escapeInput)
				{
					if (key != escapeCode[i])
					{
						matched = false;
						break;
					}
					matched = true;
				}

				if (matched)
				{
					FlxG.save.data.doisedCount = 0;
					FlxG.save.data.isDoised = false;
					FlxG.save.flush();

					FlxG.camera.fade(FlxColor.BLACK, 0);
					FlxG.sound.playMusic(Paths.music("freakyMenu"));
					Conductor.bpm = 102;
					flixel.addons.transition.FlxTransitionableState.skipNextTransIn = true;
					MusicBeatState.switchState(MainMenuState.new);
					trace("ok nvmd out of that nightmare lmao");
				}
				else
					openSubState(new DoiseJumpscare());
			}
		}
	}
}

class DoiseJumpscare extends FlxSubState
{
	var offset = FlxPoint.get();
	var spr:FlxSprite;
	var timer = 0.;
	var jumpTime = FlxG.random.float(0.6, 1.2);
	public function new()
	{
		super();
		bgColor = 0xCC000000;
		spr = new FlxSprite(Paths.image("doiseRoom/spr_rankND_15"));
		spr.setGraphicSize(0, 720);
		spr.updateHitbox();
		add(spr.screenCenter());
		FlxG.sound.play(Paths.sound("exe_scream"));
		trace("GET DOISESCARED!!!!");
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		spr.offset.subtractPoint(offset);
		offset.set(FlxG.random.float(-5, 5), FlxG.random.float(-5, 5));
		spr.offset.addPoint(offset);
		if ((timer += elapsed) > jumpTime)
			Sys.exit(0);
	}
}
