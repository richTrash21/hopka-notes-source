package options;

import flixel.util.FlxDestroyUtil;
import substates.PauseSubState;
import flixel.math.FlxPoint;

import objects.Character;
import objects.Bar;

class NoteOffsetState extends MusicBeatState
{
	var boyfriend:Character;
	var gf:Character;

	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;

	final placement:Float = FlxG.width * 0.35;
	var rating:ExtendedSprite;
	var comboNums:FlxSpriteGroup;
	var dumbTexts:FlxTypedGroup<FlxText>;

	var barPercent(default, set):Float = 0;
	final delayMin:Int = -500;
	final delayMax:Int = 500;
	var timeBar:Bar;
	var timeTxt:FlxText;
	var beatText:Alphabet;
	var beatTween:FlxTween;

	var changeModeText:FlxText;

	var controllerPointer:FlxSprite;
	var _lastControllerMode:Bool = false;

	@:noCompletion function set_barPercent(value:Float):Float
		return barPercent = FlxMath.bound(value, delayMin, delayMax);

	override public function create()
	{
		// Cameras
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camGame.active = camHUD.active = false;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		FlxG.camera.scroll.set(120, 130);

		persistentUpdate = true;
		FlxG.sound.pause();

		// Stage
		Paths.currentLevel = 'week1';
		new states.stages.StageWeek1();

		// Characters
		gf = new Character(400, 130, 'gf');
		// gf.x += gf.positionArray[0];
		// gf.y += gf.positionArray[1];
		gf.scrollFactor.set(0.95, 0.95);
		boyfriend = new Character(770, 100, 'bf', true);
		// boyfriend.x += boyfriend.positionArray[0];
		// boyfriend.y += boyfriend.positionArray[1];
		add(gf);
		add(boyfriend);

		// Combo stuff
		rating = new ExtendedSprite(0, 0, Paths.image('sick'));
		rating.cameras = [camHUD];
		rating.antialiasing = ClientPrefs.data.antialiasing;
		rating.setScale(0.7);
		rating.updateHitbox();
		add(rating);

		comboNums = new FlxSpriteGroup();
		comboNums.cameras = [camHUD];
		add(comboNums);

		for (i in 0...3)
		{
			final numScore = new ExtendedSprite(43 * i, Paths.image("num" + FlxG.random.int(0, 9)));
			numScore.cameras = [camHUD];
			numScore.antialiasing = ClientPrefs.data.antialiasing;
			numScore.setScale(0.5);
			numScore.updateHitbox();
			numScore.offset.add(FlxG.random.int(-1, 1), FlxG.random.int(-1, 1));
			comboNums.add(numScore);
		}

		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camHUD];
		add(dumbTexts);
		createTexts();

		repositionCombo();

		// Note delay stuff
		beatText = new Alphabet(0, 0, 'Beat Hit!', true);
		beatText.setScale(0.6, 0.6);
		beatText.x += 260;
		beatText.alpha = 0;
		beatText.acceleration.y = 250;
		beatText.visible = false;
		add(beatText);
		
		timeTxt = new FlxText(0, 600, FlxG.width, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		//timeTxt.scrollFactor.set();
		timeTxt.borderSize = 2;
		timeTxt.visible = false;
		timeTxt.cameras = [camHUD];

		barPercent = ClientPrefs.data.noteOffset;
		updateNoteDelay();
		
		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 3), 'healthBar', () -> barPercent, delayMin, delayMax);
		//timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.visible = false;
		timeBar.cameras = [camHUD];
		timeBar.leftBar.color = FlxColor.LIME;
		timeBar.updateCallback = (_, _) -> updateNoteDelay();
		timeBar.smooth = false;

		add(timeBar);
		add(timeTxt);

		final blackBox:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 40, 0x99000000);
		//blackBox.scrollFactor.set();
		blackBox.cameras = [camHUD];
		blackBox.active = false;
		add(blackBox);

		changeModeText = new FlxText(0, 4, FlxG.width, "", 32);
		changeModeText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		//changeModeText.scrollFactor.set();
		changeModeText.cameras = [camHUD];
		add(changeModeText);
		
		controllerPointer = new flixel.addons.display.shapes.FlxShapeCircle(0, 0, 20, {thickness: 0}, 0x99FFFFFF);
		controllerPointer.offset.set(20, 20);
		controllerPointer.screenCenter();
		controllerPointer.cameras = [camHUD];
		add(controllerPointer);
		
		updateMode();
		_lastControllerMode = true;

		Conductor.bpm = 128.0;
		FlxG.sound.playMusic(Paths.music('offsetSong'), 1, true);

		super.create();
	}

	var holdTime:Float = 0;
	var onComboMenu:Bool = true;
	var holdingObjectType:Null<Bool> = null;

	var startMousePos:FlxPoint = FlxPoint.get();
	var startComboOffset:FlxPoint = FlxPoint.get();
	var __point:FlxPoint = FlxPoint.get();

	override public function update(elapsed:Float)
	{
		final addNum:Int = FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER) ? (onComboMenu ? 10 : 3) : 1;
		if (FlxG.gamepads.anyJustPressed(ANY)) controls.controllerMode = true;
		else if (FlxG.mouse.justPressed) controls.controllerMode = false;

		if (controls.controllerMode != _lastControllerMode)
		{
			//trace('changed controller mode');
			//FlxG.mouse.visible = !controls.controllerMode;
			controllerPointer.visible = controls.controllerMode;

			// changed to controller mid state
			if (controls.controllerMode)
			{
				FlxG.mouse.getScreenPosition(camHUD, __point);
				controllerPointer.setPosition(__point.x, __point.y);
			}
			updateMode();
			_lastControllerMode = controls.controllerMode;
		}

		if (onComboMenu)
		{
			if (FlxG.keys.justPressed.ANY || FlxG.gamepads.anyJustPressed(ANY))
			{
				final controlArray:Array<Bool> = if (!controls.controllerMode)
					[
						FlxG.keys.justPressed.LEFT,
						FlxG.keys.justPressed.RIGHT,
						FlxG.keys.justPressed.UP,
						FlxG.keys.justPressed.DOWN,
					
						FlxG.keys.justPressed.A,
						FlxG.keys.justPressed.D,
						FlxG.keys.justPressed.W,
						FlxG.keys.justPressed.S
					];
				else
					[
						FlxG.gamepads.anyJustPressed(DPAD_LEFT),
						FlxG.gamepads.anyJustPressed(DPAD_RIGHT),
						FlxG.gamepads.anyJustPressed(DPAD_UP),
						FlxG.gamepads.anyJustPressed(DPAD_DOWN),
					
						FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_LEFT),
						FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_RIGHT),
						FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_UP),
						FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_DOWN)
					];

				if (controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if (controlArray[i])
						{
							switch(i)
							{
								case 0: ClientPrefs.data.comboOffset[0] -= addNum;
								case 1: ClientPrefs.data.comboOffset[0] += addNum;
								case 2: ClientPrefs.data.comboOffset[1] += addNum;
								case 3: ClientPrefs.data.comboOffset[1] -= addNum;
								case 4: ClientPrefs.data.comboOffset[2] -= addNum;
								case 5: ClientPrefs.data.comboOffset[2] += addNum;
								case 6: ClientPrefs.data.comboOffset[3] += addNum;
								case 7: ClientPrefs.data.comboOffset[3] -= addNum;
							}
						}
					}
					repositionCombo();
				}
			}
			
			// controller things
			var analogX:Float = 0;
			var analogY:Float = 0;
			var analogMoved:Bool = false;
			var gamepadPressed:Bool = false;
			var gamepadReleased:Bool = false;
			if (controls.controllerMode)
			{
				for (gamepad in FlxG.gamepads.getActiveGamepads())
				{
					analogX = gamepad.getXAxis(LEFT_ANALOG_STICK);
					analogY = gamepad.getYAxis(LEFT_ANALOG_STICK);
					analogMoved = (analogX != 0 || analogY != 0);
					if (analogMoved) break;
				}
				controllerPointer.x = Math.max(0, Math.min(FlxG.width, controllerPointer.x + analogX * 1000 * elapsed));
				controllerPointer.y = Math.max(0, Math.min(FlxG.height, controllerPointer.y + analogY * 1000 * elapsed));
				gamepadPressed = !FlxG.gamepads.anyJustPressed(START) && controls.ACCEPT;
				gamepadReleased = !FlxG.gamepads.anyJustReleased(START) && controls.justReleased('accept');
			}

			// probably there's a better way to do this but, oh well.
			if (FlxG.mouse.justPressed || gamepadPressed)
			{
				holdingObjectType = null;
				if (controls.controllerMode)
					controllerPointer.getScreenPosition(startMousePos, camHUD);
				else
					FlxG.mouse.getScreenPosition(camHUD, startMousePos);

				if (startMousePos.x - comboNums.x >= 0 && startMousePos.x - comboNums.x <= comboNums.width &&
					startMousePos.y - comboNums.y >= 0 && startMousePos.y - comboNums.y <= comboNums.height)
				{
					holdingObjectType = true;
					startComboOffset.x = ClientPrefs.data.comboOffset[2];
					startComboOffset.y = ClientPrefs.data.comboOffset[3];
				}
				else if (startMousePos.x - rating.x >= 0 && startMousePos.x - rating.x <= rating.width &&
						 startMousePos.y - rating.y >= 0 && startMousePos.y - rating.y <= rating.height)
				{
					holdingObjectType = false;
					startComboOffset.x = ClientPrefs.data.comboOffset[0];
					startComboOffset.y = ClientPrefs.data.comboOffset[1];
				}
			}
			if (FlxG.mouse.justReleased || gamepadReleased)
				holdingObjectType = null;

			if (holdingObjectType != null)
			{
				if (FlxG.mouse.justMoved || analogMoved)
				{
					if (controls.controllerMode)
						controllerPointer.getScreenPosition(__point, camHUD);
					else
						FlxG.mouse.getScreenPosition(camHUD, __point);

					final addNum:Int = holdingObjectType ? 2 : 0;
					ClientPrefs.data.comboOffset[addNum]   =  Math.round((__point.x - startMousePos.x) + startComboOffset.x);
					ClientPrefs.data.comboOffset[addNum+1] = -Math.round((__point.y - startMousePos.y) - startComboOffset.y);
					repositionCombo();
				}
			}

			if (controls.RESET)
			{
				for (i in 0...ClientPrefs.data.comboOffset.length)
					ClientPrefs.data.comboOffset[i] = 0;
				
				repositionCombo();
			}
		}
		else
		{
			if (controls.UI_LEFT_P)
				barPercent = ClientPrefs.data.noteOffset - 1;
			else if (controls.UI_RIGHT_P)
				barPercent = ClientPrefs.data.noteOffset + 1;

			if (controls.UI_LEFT || controls.UI_RIGHT) holdTime += elapsed;
			if (controls.UI_LEFT_R || controls.UI_RIGHT_R) holdTime = 0;

			if (holdTime > 0.5)
				barPercent += 100 * addNum * elapsed * (controls.UI_LEFT ? -1 : 1);

			if (controls.RESET)
			{
				holdTime = 0;
				barPercent = 0;
			}
		}

		if ((!controls.controllerMode && controls.ACCEPT) ||
		(controls.controllerMode && FlxG.gamepads.anyJustPressed(START)))
		{
			onComboMenu = !onComboMenu;
			updateMode();
		}

		if (controls.BACK)
		{
			if (zoomTween != null) zoomTween.cancel();
			if (beatTween != null) beatTween.cancel();

			persistentUpdate = false;
			FlxG.switchState(options.OptionsState.new);
			if (OptionsState.onPlayState)
			{
				if (ClientPrefs.data.pauseMusic != 'None')
					FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(PauseSubState.songName ?? ClientPrefs.data.pauseMusic)))
				else
					FlxG.sound.music.volume = 0;
			}
			else
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			//FlxG.mouse.visible = false;
		}

		Conductor.songPosition = FlxG.sound.music.time;
		super.update(elapsed);
	}

	override function destroy()
	{
		startMousePos.put();
		startComboOffset.put();
		__point.put();

		super.destroy();
		beatTween = null;
		zoomTween = null;
		boyfriend = null;
		gf = null;
		rating = null;
		comboNums = null;
		dumbTexts = null;
		timeBar = null;
		timeTxt = null;
		beatText = null;
		changeModeText = null;
		controllerPointer = null;
		camHUD = null;
		camGame = null;
	}

	var zoomTween:FlxTween;
	var lastBeatHit:Int = -1;
	override public function beatHit()
	{
		super.beatHit();

		if (lastBeatHit == curBeat) return;

		if (FlxMath.isEven(curBeat))
		{
			boyfriend.dance();
			gf.dance();
		}
		
		if (curBeat % 4 == 2)
		{
			FlxG.camera.zoom = 1.15;

			if (zoomTween != null) zoomTween.cancel();
			zoomTween = FlxTween.tween(FlxG.camera, {zoom: 1}, 1, {ease: FlxEase.circOut, onComplete: (_) -> zoomTween = null});

			beatText.alpha = 1;
			beatText.y = 320;
			beatText.velocity.y = -150;
			if (beatTween != null) beatTween.cancel();
			beatTween = FlxTween.num(1, 0, 1, {ease: FlxEase.sineIn, onComplete: (_) -> beatTween = null}, (a) -> beatText.alpha = a);
		}

		lastBeatHit = curBeat;
	}

	function repositionCombo()
	{
		rating.x = placement - 40 + ClientPrefs.data.comboOffset[0];
		rating.screenCenter(Y).y -= 60 + ClientPrefs.data.comboOffset[1];

		comboNums.x = placement - 90 + ClientPrefs.data.comboOffset[2];
		comboNums.screenCenter(Y).y += 80 - ClientPrefs.data.comboOffset[3];
		reloadTexts();
	}

	function createTexts()
	{
		for (i in 0...4)
		{
			final text:FlxText = new FlxText(10, (i > 1 ? 72 : 48) + (i * 30), 0, '', 24);
			text.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			//text.scrollFactor.set();
			text.borderSize = 2;
			dumbTexts.add(text);
			text.cameras = [camHUD];
		}
	}

	function reloadTexts()
	{
		for (i in 0...dumbTexts.length)
		{
			switch(i)
			{
				case 0: dumbTexts.members[i].text = 'Rating Offset:';
				case 1: dumbTexts.members[i].text = '[' + ClientPrefs.data.comboOffset[0] + ', ' + ClientPrefs.data.comboOffset[1] + ']';
				case 2: dumbTexts.members[i].text = 'Numbers Offset:';
				case 3: dumbTexts.members[i].text = '[' + ClientPrefs.data.comboOffset[2] + ', ' + ClientPrefs.data.comboOffset[3] + ']';
			}
		}
	}

	function updateNoteDelay()
	{
		ClientPrefs.data.noteOffset = Math.round(barPercent);
		timeTxt.text = 'Current offset: ' + Math.floor(barPercent) + ' ms';
	}

	function updateMode()
	{
		rating.visible = onComboMenu;
		comboNums.visible = onComboMenu;
		dumbTexts.visible = onComboMenu;
		
		timeBar.visible = !onComboMenu;
		timeTxt.visible = !onComboMenu;
		beatText.visible = !onComboMenu;

		controllerPointer.visible = false;
		//FlxG.mouse.visible = false;
		if (onComboMenu)
		{
			//FlxG.mouse.visible = !controls.controllerMode;
			controllerPointer.visible = controls.controllerMode;
		}

		final str:String = onComboMenu ? 'Combo Offset' : 'Note/Beat Delay';
		final str2:String = controls.controllerMode ? '(Press Start to Switch)' : '(Press Accept to Switch)';
		changeModeText.text = '< ${str.toUpperCase()} ${str2.toUpperCase()} >';
	}
}
