package options;

import flixel.util.FlxDestroyUtil;
import haxe.extern.EitherType;

import backend.InputFormatter;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import objects.AttachedSprite;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;

abstract ControlsOption(Array<EitherType<Bool, String>>) from Array<EitherType<Bool, String>> to Array<EitherType<Bool, String>>
{
	public var showOnGamepad(get, never):Bool;
	public var displayName(get, never):String;
	public var rebindName(get, never):String;
	public var saveKey(get, never):String;

	public var isDisplayName(get, never):Bool;
	public var isEmpty(get, never):Bool;

	@:noCompletion inline function get_showOnGamepad():Bool	 return this[0];
	@:noCompletion inline function get_displayName():String	 return this[1];
	@:noCompletion inline function get_rebindName():String	 return this[3];
	@:noCompletion inline function get_saveKey():String		 return this[2];

	@:noCompletion inline function get_isDisplayName():Bool	 return this.length == 2 /*|| (rebindName == null && saveKey == null)*/;
	@:noCompletion inline function get_isEmpty():Bool		 return this.length == 1 /*|| (displayName == null && rebindName == null && saveKey == null)*/;
}

@:allow(options.RemapKeybindScreen)
class ControlsSubState extends MusicBeatSubstate
{
	inline static var gamepadColor:FlxColor = 0xfffd7194;
	inline static var keyboardColor:FlxColor = 0xff7192fd;

	var curSelected:Int = 0;
	var curAlt:Bool = false;

	// Show on gamepad - Display name - Save file key - Rebind display name
	static final defaultOptions:Array<ControlsOption> = [
		[true, "NOTES"],
		[true, "Left", "note_left", "Note Left"],
		[true, "Down", "note_down", "Note Down"],
		[true, "Up", "note_up", "Note Up"],
		[true, "Right", "note_right", "Note Right"],
		[true],
		[true, "UI"],
		[true, "Left", "ui_left", "UI Left"],
		[true, "Down", "ui_down", "UI Down"],
		[true, "Up", "ui_up", "UI Up"],
		[true, "Right", "ui_right", "UI Right"],
		[true],
		[true, "Reset", "reset", "Reset"],
		[true, "Accept", "accept", "Accept"],
		[true, "Back", "back", "Back"],
		[true, "Pause", "pause", "Pause"],
		[false],
		[false, "VOLUME"],
		[false, "Mute", "volume_mute", "Volume Mute"],
		[false, "Up", "volume_up", "Volume Up"],
		[false, "Down", "volume_down", "Volume Down"]
		#if !RELESE_BUILD_FR ,
		[false],
		[false, "DEBUG"],
		[false, "Key 1", "debug_1", "Debug Key #1"],
		[false, "Key 2", "debug_2", "Debug Key #2"]
		#end
	];
	var options:Array<ControlsOption>;
	var curOptions:Array<Int>;
	var curOptionsValid:Array<Int>;
	static final defaultKey:String = "Reset to Default Keys";

	var bg:FlxSprite;
	var grpDisplay:FlxTypedGroup<Alphabet>;
	var grpBlacks:FlxTypedGroup<AttachedSprite>;
	var grpOptions:FlxTypedGroup<Alphabet>;
	var grpBinds:FlxTypedGroup<Alphabet>;
	var selectSpr:AttachedSprite;

	var onKeyboardMode:Bool = true;
	
	var controllerSpr:FlxSprite;
	var rebindScreen:RemapKeybindScreen;
	
	public function new()
	{
		super();
		persistentUpdate = true;
		destroySubStates = false;
		rebindScreen = new RemapKeybindScreen(this);

		options = defaultOptions.copy();
		options.push([true]);
		options.push([true]);
		options.push([true, defaultKey]);

		// bg = new ExtendedSprite("menuDesat");
		bg = cast FlxG.state.members[0];
		bg.color = keyboardColor;
		// bg.active = false;
		// add(bg.screenCenter());

		final grid = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		grid.alpha = 0;
		FlxTween.num(0, 1, 0.5, {ease: FlxEase.quadOut}, (a) -> grid.alpha = a);
		add(grid);

		add(grpDisplay = new FlxTypedGroup<Alphabet>());
		add(grpOptions = new FlxTypedGroup<Alphabet>());
		add(grpBlacks  = new FlxTypedGroup<AttachedSprite>());

		selectSpr = new AttachedSprite();
		selectSpr.makeGraphic(250, 78, FlxColor.WHITE);
		selectSpr.copyAlpha = false;
		selectSpr.alpha = 0.75;
		add(selectSpr);

		add(grpBinds = new FlxTypedGroup<Alphabet>());

		controllerSpr = new FlxSprite(50, 40).loadGraphic(Paths.image("controllertype"), true, 82, 60);
		controllerSpr.antialiasing = ClientPrefs.data.antialiasing;
		controllerSpr.animation.add("keyboard", [0], 1, false);
		controllerSpr.animation.add("gamepad", [1], 1, false);
		add(controllerSpr);

		final text = new Alphabet(60, 90, "CTRL", false);
		text.alignment = CENTERED;
		text.setScale(0.4);
		text.active = false;
		add(text);

		createTexts();
	}

	var lastID:Int = 0;
	function createTexts()
	{
		curOptions = [];
		curOptionsValid = [];
		grpDisplay.forEachAlive((text) -> text.destroy());
		grpBlacks.forEachAlive((black) -> black.destroy());
		grpOptions.forEachAlive((text) -> text.destroy());
		grpBinds.forEachAlive((text)   -> text.destroy());
		grpDisplay.clear();
		grpBlacks.clear();
		grpOptions.clear();
		grpBinds.clear();

		var myID = 0;
		for (i in 0...options.length)
		{
			final option = options[i];
			if (!option.showOnGamepad && !onKeyboardMode)
				continue;

			if (!option.isEmpty)
			{
				final isCentered = option.isDisplayName;
				final isDisplayKey = isCentered && option.displayName != defaultKey;

				final text = new Alphabet(200, 300, option.displayName, !isDisplayKey);
				text.isMenuItem = true;
				text.changeX = false;
				text.distancePerItem.y = 60;
				text.targetY = myID;
				if (isDisplayKey)
					grpDisplay.add(text);
				else
				{
					grpOptions.add(text);
					curOptions.push(i);
					curOptionsValid.push(myID);
				}
				text.ID = myID;
				lastID = myID;

				if (isCentered)
					addCenteredText(text, myID);
				else
					addKeyText(text, option, myID);

				text.snapToPosition();
				text.y += FlxG.height * 2;
			}
			myID++;
		}
		updateText();
	}

	function addCenteredText(text:Alphabet, id:Int)
	{
		text.screenCenter(X);
		text.y -= 55;
		text.startPosition.y -= 55;
	}

	function addKeyText(text:Alphabet, option:ControlsOption, id:Int)
	{
		for (n in 0...2)
		{
			final textX = 350 + n * 300;
			var key:String;
			if (onKeyboardMode)
			{
				final savKey:Array<Null<FlxKey>> = ClientPrefs.keyBinds.get(option.saveKey);
				key = InputFormatter.getKeyName(savKey[n] ?? NONE);
			}
			else
			{
				final savKey:Array<Null<FlxGamepadInputID>> = ClientPrefs.gamepadBinds.get(option.saveKey);
				key = InputFormatter.getGamepadName(savKey[n] ?? NONE);
			}

			final attach:Alphabet = new Alphabet(textX + 210, 248, key, false);
			attach.isMenuItem = true;
			attach.changeX = false;
			attach.distancePerItem.y = 60;
			attach.targetY = text.targetY;
			attach.ID = Math.floor(grpBinds.length * .5);
			attach.snapToPosition();
			attach.y += FlxG.height * 2;
			grpBinds.add(attach);

			playstationCheck(attach);
			attach.scaleX = Math.min(1, 230 / attach.width);

			// spawn black bars at the right of the key name
			final black = new AttachedSprite();
			black.makeGraphic(250, 78, FlxColor.BLACK);
			black.alphaMult = 0.4;
			black.sprTracker = text;
			black.yAdd = -6;
			black.xAdd = textX;
			grpBlacks.add(black);
		}
	}

	function playstationCheck(alpha:Alphabet)
	{
		if (onKeyboardMode || FlxG.gamepads.firstActive == null || FlxG.gamepads.firstActive.detectedModel != PS4)
			return;

		final letter = alpha.members[0];
		switch (alpha.text)
		{
			case "[", "]": // Square and Triangle respectively
				letter.image = "alphabet_playstation";
				letter.updateHitbox();
				letter.offset.add(4, -5);
				// letter.offset.x += 4;
				// letter.offset.y -= 5;
		}
	}

	/*function updateBind(num:Int, text:String)
	{
		final bind:Alphabet = grpBinds.members[num];
		final attach:Alphabet = new Alphabet(350 + (num & 1) * 300, 248, text, false);
		attach.isMenuItem = true;
		attach.changeX = false;
		attach.distancePerItem.y = 60;
		attach.targetY = bind.targetY;
		attach.ID = bind.ID;
		attach.x = bind.x;
		attach.y = bind.y;
		
		playstationCheck(attach);
		attach.scaleX = Math.min(1, 230 / attach.width);

		bind.kill();
		grpBinds.remove(bind);
		grpBinds.insert(num, attach);
		bind.destroy();
	}*/

	// var binding:Bool = false;
	var holdingEsc:Float = 0;
	// var bindingBlack:FlxSprite;
	// var bindingText:Alphabet;
	// var bindingText2:Alphabet;

	var timeForMoving:Float = 0.1;
	override function update(elapsed:Float)
	{
		if (timeForMoving > 0) // Fix controller bug
		{
			timeForMoving = Math.max(0, timeForMoving - elapsed);
			return super.update(elapsed);
		}

		if (subState != null) // (!binding)
			return super.update(elapsed);

		if ((FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE) || FlxG.gamepads.anyJustPressed(B))
		{
			close();
			FlxG.sound.play(Paths.sound("cancelMenu"));
			return;
		}
		if (FlxG.keys.justPressed.CONTROL || FlxG.gamepads.anyJustPressed(LEFT_SHOULDER) || FlxG.gamepads.anyJustPressed(RIGHT_SHOULDER))
			swapMode();

		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT || FlxG.gamepads.anyJustPressed(DPAD_LEFT) || FlxG.gamepads.anyJustPressed(DPAD_RIGHT) ||
			FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_LEFT) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_RIGHT))
			updateAlt(true);

		final MOUSE = FlxG.mouse.wheel != 0;
		final UP = FlxG.keys.justPressed.UP || FlxG.gamepads.anyJustPressed(DPAD_UP) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_UP);
		final DOWN = FlxG.keys.justPressed.DOWN || FlxG.gamepads.anyJustPressed(DPAD_DOWN) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_DOWN);
		if (MOUSE || (UP || DOWN))
			updateText(MOUSE ? -FlxG.mouse.wheel : (UP ? -1 : 1));

		if (FlxG.keys.justPressed.ENTER || FlxG.gamepads.anyJustPressed(START) || FlxG.gamepads.anyJustPressed(A))
		{
			final curOption = options[curOptions[curSelected]];
			if (curOption.displayName == defaultKey)
			{
				// Reset to Default
				ClientPrefs.resetKeys(!onKeyboardMode);
				ClientPrefs.reloadVolumeKeys();
				final lastSel = curSelected;
				createTexts();
				curSelected = lastSel;
				updateText();
				FlxG.sound.play(Paths.sound("cancelMenu"));
			}
			else
				openSubState(rebindScreen);
		}
		super.update(elapsed);
	}

	function updateText(move:Int = 0)
	{
		if (move != 0) curSelected = FlxMath.wrap(curSelected + move, 0, curOptions.length-1);

		final num:Int = curOptionsValid[curSelected];
		final addNum:Int = num < 3 ? 3 - num : num > lastID - 4 ? (lastID - 4) - num : 0;
		grpDisplay.forEachAlive(function(item:Alphabet) item.targetY = item.ID - num - addNum);

		grpOptions.forEachAlive(function(item:Alphabet)
		{
			item.targetY = item.ID - num - addNum;
			item.alpha = (item.ID - num == 0) ? 1 : 0.6;
		});
		grpBinds.forEachAlive(function(item:Alphabet)
		{
			final parent:Alphabet = grpOptions.members[item.ID];
			item.targetY = parent.targetY;
			item.alpha = parent.alpha;
		});

		updateAlt();
		FlxG.sound.play(Paths.sound("scrollMenu"));
	}

	var colorTween:FlxTween;
	function swapMode()
	{
		if (colorTween != null)
			colorTween.destroy();
		colorTween = FlxTween.color(bg, 0.5, bg.color, onKeyboardMode ? gamepadColor : keyboardColor);
		onKeyboardMode = !onKeyboardMode;

		curSelected = 0;
		curAlt = false;
		controllerSpr.animation.play(onKeyboardMode ? "keyboard" : "gamepad");
		createTexts();
	}

	function updateAlt(doSwap:Bool = false)
	{
		if (doSwap)
		{
			curAlt = !curAlt;
			FlxG.sound.play(Paths.sound("scrollMenu"));
		}
		selectSpr.sprTracker = grpBlacks.members[Math.floor(curSelected * 2) + (curAlt ? 1 : 0)];
		selectSpr.visible = (selectSpr.sprTracker != null);
	}

	override function destroy()
	{		
		options = null;
		curOptions = null;
		curOptionsValid = null;

		rebindScreen = FlxDestroyUtil.destroy(rebindScreen);
		grpDisplay = null;
		grpBlacks = null;
		grpOptions = null;
		grpBinds = null;
		selectSpr = null;
		controllerSpr = null;
		if (colorTween != null)
			colorTween.cancel();
		colorTween = null;
		super.destroy();
		bg.color = OptionsState.BG_COLOR;
		bg = null;
	}
}

// seperate remap screen from the menu
// also it's really funny that you can open substates inside substates
// but also really practical!
// - rich
private class RemapKeybindScreen extends flixel.FlxSubState
{
	var parent:ControlsSubState;
	var curOption:ControlsOption;
	var holdingEsc = 0.;

	var bindingText:Alphabet;
	var bindingText2:Alphabet;

	// var __timer = 0.;
	var __justOpened = true;

	public function new(parent:ControlsSubState)
	{
		this.parent = parent;
		// this.curOption = curOption;
		super(0x00FFFFFF);
		/*FlxTween.num(0, .6, .5, null, (a) -> { bgColor.alphaFloat = a; if (FlxG.renderTile) bgColor = bgColor;});

		final bindingText = new Alphabet(FlxG.width * .5, 160, "Rebinding " + curOption.rebindName, false);
		bindingText.alignment = CENTERED;
		add(bindingText);
		
		final bindingText2 = new Alphabet(FlxG.width * .5, 340, "Hold ESC to Cancel\nHold Backspace to Delete", true);
		bindingText2.alignment = CENTERED;
		add(bindingText2);

		// parent.binding = true;
		ClientPrefs.toggleVolumeKeys(false);
		FlxG.sound.play(Paths.sound("scrollMenu"));*/

		openCallback = () ->
		{
			// __timer = .01;
			__justOpened = true;
			bgColor.alpha = 0;
			if (FlxG.renderTile)
				bgColor = bgColor;
			FlxTween.num(0, .6, .5, (a) -> { bgColor.alphaFloat = a; if (FlxG.renderTile) bgColor = bgColor;});

			curOption = this.parent.options[this.parent.curOptions[this.parent.curSelected]];
	
			add(bindingText = new Alphabet(FlxG.width * .5, 160, "Rebinding " + curOption.rebindName, false));
			bindingText.alignment = CENTERED;
			bindingText.alpha = 0;

			add(bindingText2 = new Alphabet(FlxG.width * .5, 340, "Hold ESC to Cancel\nHold Backspace to Delete", true));
			bindingText2.alignment = CENTERED;
			bindingText2.alpha = 0;

			FlxTween.num(0, 1, .2, (a) -> bindingText.alpha = bindingText2.alpha = a);

			// parent.binding = true;
			ClientPrefs.toggleVolumeKeys(false);
			FlxG.sound.play(Paths.sound("scrollMenu"));
		}
	}

	override function update(elapsed:Float)
	{
		if (__justOpened) // (__timer > 0)
		{
			// __timer -= elapsed;
			__justOpened = false;
			return super.update(elapsed);
		}
	
		final altNum = parent.curAlt ? 1 : 0;
		final curSelected = parent.curSelected;
		final onKeyboardMode = parent.onKeyboardMode;

		if (FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
		{
			if ((holdingEsc += elapsed) > 0.5)
			{
				FlxG.sound.play(Paths.sound("cancelMenu"));
				// closeBinding();
				close();
			}
		}
		else if (FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
		{
			if ((holdingEsc += elapsed) > 0.5)
			{
				ClientPrefs.keyBinds.get(curOption.saveKey)[altNum] = NONE;
				ClientPrefs.clearInvalidKeys(curOption.saveKey);
				/*parent.*/updateBind(Math.floor(curSelected * 2) + altNum, onKeyboardMode ? InputFormatter.getKeyName(NONE) : InputFormatter.getGamepadName(NONE));
				FlxG.sound.play(Paths.sound("cancelMenu"));
				// closeBinding();
				close();
			}
		}
		else
		{
			holdingEsc = 0;
			var changed = false;
			final curKeys = ClientPrefs.keyBinds.get(curOption.saveKey);
			final curButtons = ClientPrefs.gamepadBinds.get(curOption.saveKey);

			if (onKeyboardMode)
			{
				if (FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
				{
					final keyPressed = FlxG.keys.firstJustPressed();
					final keyReleased = FlxG.keys.firstJustReleased();
					if (keyPressed > -1 && !(keyPressed == ESCAPE || keyPressed == BACKSPACE))
					{
						curKeys[altNum] = keyPressed;
						changed = true;
					}
					else if (keyReleased > -1 && (keyReleased == ESCAPE || keyReleased == BACKSPACE))
					{
						curKeys[altNum] = keyReleased;
						changed = true;
					}
				}
			}
			else if (FlxG.gamepads.anyJustPressed(ANY) || FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER) || FlxG.gamepads.anyJustReleased(ANY))
			{
				var keyPressed:Null<FlxGamepadInputID> = NONE;
				var keyReleased:Null<FlxGamepadInputID> = NONE;
				if (FlxG.gamepads.anyJustPressed(LEFT_TRIGGER))
					keyPressed = LEFT_TRIGGER; // it wasnt working for some reason
				else if (FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					keyPressed = RIGHT_TRIGGER; // it wasnt working for some reason
				else
				{
					for (i in 0...FlxG.gamepads.numActiveGamepads)
					{
						final gamepad = FlxG.gamepads.getByID(i);
						if (gamepad == null)
							continue;

						keyPressed = gamepad.firstJustPressedID() ?? NONE;
						keyReleased = gamepad.firstJustReleasedID() ?? NONE;
						if (!(keyPressed == NONE && keyReleased == NONE))
							break;
					}
				}

				if (!(keyPressed == NONE || keyPressed == BACK || keyPressed == B))
				{
					curButtons[altNum] = keyPressed;
					changed = true;
				}
				else if (keyReleased != NONE && (keyReleased == BACK || keyReleased == B))
				{
					curButtons[altNum] = keyReleased;
					changed = true;
				}
			}

			if (changed)
			{
				if (onKeyboardMode)
				{
					if (curKeys[altNum] == curKeys[1 - altNum])
						curKeys[1 - altNum] = NONE;
				}
				else
				{
					if (curButtons[altNum] == curButtons[1 - altNum])
						curButtons[1 - altNum] = NONE;
				}

				final option = curOption.saveKey;
				ClientPrefs.clearInvalidKeys(option);
				for (n in 0...2)
				{
					var key:String;
					if (onKeyboardMode)
					{
						final savKey:Array<Null<FlxKey>> = ClientPrefs.keyBinds.get(option);
						key = InputFormatter.getKeyName(savKey[n] ?? NONE);
					}
					else
					{
						final savKey:Array<Null<FlxGamepadInputID>> = ClientPrefs.gamepadBinds.get(option);
						key = InputFormatter.getGamepadName(savKey[n] ?? NONE);
					}
					/*parent.*/updateBind(Math.floor(curSelected * 2) + n, key);
				}
				FlxG.sound.play(Paths.sound("confirmMenu"));
				// closeBinding();
				close();
			}
		}
		super.update(elapsed);
	}

	override public function close()
	{
		// parent.binding = false;
		remove(bindingText).destroy();
		remove(bindingText2).destroy();
		ClientPrefs.reloadVolumeKeys();
		super.close();
	}

	override function destroy()
	{
		bindingText = null;
		bindingText2 = null;
		super.destroy();
	}

	function updateBind(num:Int, text:String)
	{
		final bind = parent.grpBinds.members[num];
		final attach = new Alphabet(350 + (num & 1) * 300, 248, text, false);
		attach.isMenuItem = true;
		attach.changeX = false;
		attach.distancePerItem.y = 60;
		attach.targetY = bind.targetY;
		attach.ID = bind.ID;

		attach.setPosition(bind.x, bind.y);
		parent.playstationCheck(attach);
		attach.scaleX = Math.min(1, 230 / attach.width);

		parent.grpBinds.remove(bind).destroy();
		parent.grpBinds.insert(num, attach);
	}
}