package states;

import backend.WeekData;
import backend.Mods;

import flixel.ui.FlxButton;
import flixel.FlxBasic;
import openfl.display.BitmapData;
import flash.geom.Rectangle;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import haxe.extern.EitherType;

import objects.AttachedSprite;

class ModsMenuState extends MusicBeatState
{
	var mods:Array<ModMetadataClass> = [];
	static var changedAThing = false;
	var bg:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;

	var noModsTxt:FlxText;
	var selector:AttachedSprite;
	var descriptionTxt:FlxText;
	var needaReset = false;
	private static var curSelected:Int = 0;
	public static var defaultColor:FlxColor = 0xFF665AFF;

	var buttonDown:FlxButton;
	var buttonTop:FlxButton;
	var buttonDisableAll:FlxButton;
	var buttonEnableAll:FlxButton;
	var buttonUp:FlxButton;
	var buttonToggle:FlxButton;
	var buttonsArray:Array<FlxButton> = [];

	var installButton:FlxButton;
	var removeButton:FlxButton;

	var modsList = new Array<Array<EitherType<String, Bool>>>();

	var visibleWhenNoMods:Array<FlxBasic> = [];
	var visibleWhenHasMods:Array<FlxBasic> = [];

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		WeekData.setDirectoryFromWeek();

		#if hxdiscord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		bg = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		noModsTxt = new FlxText(0, 0, FlxG.width, "NO MODS INSTALLED\nPRESS BACK TO EXIT AND INSTALL A MOD", 48);
		if(FlxG.random.bool(0.1)) noModsTxt.text += '\nBITCH.'; //meanie
		noModsTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		noModsTxt.scrollFactor.set();
		noModsTxt.borderSize = 2;
		add(noModsTxt);
		noModsTxt.screenCenter();
		visibleWhenNoMods.push(noModsTxt);

		var list:ModsList = Mods.parseList();
		for (mod in list.all)
			modsList.push([mod, list.enabled.contains(mod)]);

		selector = new AttachedSprite();
		selector.xAdd = -205;
		selector.yAdd = -68;
		selector.alphaMult = 0.5;
		makeSelectorGraphic();
		add(selector);
		visibleWhenHasMods.push(selector);

		//attached buttons
		var startX:Int = 1120;

		buttonToggle = new FlxButton(startX, 0, "ON", function()
		{
			if (mods[curSelected].restart)
				needaReset = true;
			modsList[curSelected][1] = !modsList[curSelected][1];
			updateButtonToggle();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonToggle.setGraphicSize(50, 50);
		buttonToggle.updateHitbox();
		add(buttonToggle);
		buttonsArray.push(buttonToggle);
		visibleWhenHasMods.push(buttonToggle);

		buttonToggle.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
		setAllLabelsOffset(buttonToggle, -15, 10);
		startX -= 70;

		buttonUp = new FlxButton(startX, 0, "/\\", function()
		{
			moveMod(-1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonUp.setGraphicSize(50, 50);
		buttonUp.updateHitbox();
		add(buttonUp);
		buttonsArray.push(buttonUp);
		visibleWhenHasMods.push(buttonUp);
		buttonUp.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
		setAllLabelsOffset(buttonUp, -15, 10);
		startX -= 70;

		buttonDown = new FlxButton(startX, 0, "\\/", function() {
			moveMod(1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonDown.setGraphicSize(50, 50);
		buttonDown.updateHitbox();
		add(buttonDown);
		buttonsArray.push(buttonDown);
		visibleWhenHasMods.push(buttonDown);
		buttonDown.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
		setAllLabelsOffset(buttonDown, -15, 10);

		startX -= 100;
		buttonTop = new FlxButton(startX, 0, "TOP", function() {
			final doRestart = (mods[0].restart || mods[curSelected].restart);
			for (i in 0...curSelected)
				moveMod(-1, true); // so it shifts to the top instead of replacing the top one
			if (doRestart)
				needaReset = true;
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonTop.setGraphicSize(80, 50);
		buttonTop.updateHitbox();
		buttonTop.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
		setAllLabelsOffset(buttonTop, 0, 10);
		add(buttonTop);
		buttonsArray.push(buttonTop);
		visibleWhenHasMods.push(buttonTop);


		startX -= 190;
		buttonDisableAll = new FlxButton(startX, 0, "DISABLE ALL", function() {
			for (i in modsList)
				i[1] = false;
			for (mod in mods)
			{
				if (mod.restart)
				{
					needaReset = true;
					break;
				}
			}
			updateButtonToggle();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonDisableAll.setGraphicSize(170, 50);
		buttonDisableAll.updateHitbox();
		buttonDisableAll.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
		buttonDisableAll.label.fieldWidth = 170;
		setAllLabelsOffset(buttonDisableAll, 0, 10);
		add(buttonDisableAll);
		buttonsArray.push(buttonDisableAll);
		visibleWhenHasMods.push(buttonDisableAll);

		startX -= 190;
		buttonEnableAll = new FlxButton(startX, 0, "ENABLE ALL", function() {
			for (i in modsList)
				i[1] = true;
			for (mod in mods)
			{
				if (mod.restart)
				{
					needaReset = true;
					break;
				}
			}
			updateButtonToggle();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonEnableAll.setGraphicSize(170, 50);
		buttonEnableAll.updateHitbox();
		buttonEnableAll.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
		buttonEnableAll.label.fieldWidth = 170;
		setAllLabelsOffset(buttonEnableAll, 0, 10);
		add(buttonEnableAll);
		buttonsArray.push(buttonEnableAll);
		visibleWhenHasMods.push(buttonEnableAll);

		// more buttons
		descriptionTxt = new FlxText(148, 0, FlxG.width - 216, "", 32);
		descriptionTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT);
		descriptionTxt.scrollFactor.set();
		add(descriptionTxt);
		visibleWhenHasMods.push(descriptionTxt);

		var i:Int = 0;
		var len:Int = modsList.length;
		while (i < modsList.length)
		{
			final values = modsList[i];
			if (!FileSystem.exists(Paths.mods(values[0])))
			{
				modsList.remove(modsList[i]);
				continue;
			}

			var newMod = new ModMetadataClass(values[0]);
			mods.push(newMod);

			newMod.alphabet = new Alphabet(0, 0, mods[i].name, true);
			var scale:Float = Math.min(840 / newMod.alphabet.width, 1);
			newMod.alphabet.setScale(scale);
			newMod.alphabet.y = i * 150;
			newMod.alphabet.x = 310;
			add(newMod.alphabet);
			//Don't ever cache the icons, it's a waste of loaded memory
			var loadedIcon:BitmapData = null;
			var iconToUse:String = Paths.mods(values[0] + '/pack.png');
			if(FileSystem.exists(iconToUse)) loadedIcon = BitmapData.fromFile(iconToUse);

			newMod.icon = new AttachedSprite();
			if(loadedIcon != null)
			{
				newMod.icon.loadGraphic(loadedIcon, true, 150, 150);//animated icon support
				var totalFrames = Math.floor(loadedIcon.width * 0.006666666666666667) * Math.floor(loadedIcon.height * 0.006666666666666667); // / 150
				newMod.icon.animation.add("icon", [for (i in 0...totalFrames) i],10);
				newMod.icon.animation.play("icon");
			}
			else
			{
				newMod.icon.loadGraphic(Paths.image('unknownMod'));
			}
			newMod.icon.sprTracker = newMod.alphabet;
			newMod.icon.xAdd = -newMod.icon.width - 30;
			newMod.icon.yAdd = -45;
			add(newMod.icon);
			i++;
		}

		if(curSelected >= mods.length) curSelected = 0;

		bg.color = mods.length < 1 ? defaultColor : mods[curSelected].color;

		intendedColor = bg.color;
		changeSelection();
		updatePosition();
		FlxG.sound.play(Paths.sound('scrollMenu'));

		// FlxG.mouse.visible = true;

		super.create();
	}

	function updateButtonToggle()
	{
		if (modsList[curSelected][1])
		{
			buttonToggle.label.text = "ON";
			buttonToggle.color = FlxColor.GREEN;
		}
		else
		{
			buttonToggle.label.text = "OFF";
			buttonToggle.color = FlxColor.RED;
		}
	}

	function moveMod(change:Int, skipResetCheck:Bool = false)
	{
		if(mods.length > 1)
		{
			var doRestart:Bool = (mods[0].restart);

			var newPos:Int = curSelected + change;
			if(newPos < 0)
			{
				modsList.push(modsList.shift());
				mods.push(mods.shift());
			}
			else if(newPos >= mods.length)
			{
				modsList.insert(0, modsList.pop());
				mods.insert(0, mods.pop());
			}
			else
			{
				var lastArray:Array<EitherType<String, Bool>> = modsList[curSelected];
				modsList[curSelected] = modsList[newPos];
				modsList[newPos] = lastArray;

				var lastMod = mods[curSelected];
				mods[curSelected] = mods[newPos];
				mods[newPos] = lastMod;
			}
			changeSelection(change);

			if(!doRestart) doRestart = mods[curSelected].restart;
			if(!skipResetCheck && doRestart) needaReset = true;
		}
	}

	function saveTxt()
	{
		var fileStr = "";
		for (values in modsList)
		{
			if (fileStr.length != 0)
				fileStr += "\n";
			fileStr += values[0] + "|" + (values[1] ? "1" : "0");
		}

		File.saveContent("modsList.txt", fileStr);
		Mods.pushGlobalMods();
	}

	var noModsSine:Float = 0;
	var canExit:Bool = true;
	override function update(elapsed:Float)
	{
		if (noModsTxt.visible)
		{
			noModsSine += 180 * elapsed;
			noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) * 0.005555555555555556); // / 180
		}

		if (canExit && controls.BACK)
		{
			if (colorTween != null) 
				colorTween.cancel();
			colorTween = null;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			// FlxG.mouse.visible = false;
			saveTxt();
			if (needaReset)
			{
				// MusicBeatState.switchState(TitleState.new);
				TitleState.skippedIntro = false;
				FlxG.sound.music.fadeOut(0.3);
				if (FreeplayState.vocals != null)
				{
					FreeplayState.vocals.fadeOut(0.3);
					FreeplayState.vocals = null;
				}
				FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
			}
			else
				MusicBeatState.switchState(MainMenuState.new);
		}

		if (controls.UI_UP_P)	changeSelection(-1);
		if (controls.UI_DOWN_P)	changeSelection(1);
		updatePosition(elapsed);
		super.update(elapsed);
	}

	inline function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets) point.set(x, y);
	}

	function changeSelection(change = 0)
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		final noMods = (mods.length == 0);
		for (obj in visibleWhenHasMods) obj.visible = !noMods;
		for (obj in visibleWhenNoMods)  obj.visible = noMods;
		if (noMods)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, mods.length-1);

		final newColor = mods[curSelected].color;
		if (newColor != intendedColor)
		{
			if (colorTween != null)
				colorTween.cancel();
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {onComplete: (_) -> colorTween = null});
		}

		var i:Int = 0;
		for (mod in mods)
		{
			mod.alphabet.alpha = 0.6;
			if (i == curSelected)
			{
				mod.alphabet.alpha = 1;
				selector.sprTracker = mod.alphabet;
				descriptionTxt.text = mod.description;
				if (mod.restart) //finna make it to where if nothing changed then it won't reset
					descriptionTxt.text += " (This Mod will restart the game!)";

				// correct layering
				var stuffArray:Array<FlxSprite> = [/*removeButton, installButton,*/ selector, descriptionTxt, mod.alphabet, mod.icon];
				for (obj in stuffArray)
				{
					remove(obj);
					insert(members.length, obj);
				}
				for (obj in buttonsArray)
				{
					remove(obj);
					insert(members.length, obj);
				}
			}
			i++;
		}
		updateButtonToggle();
	}

	function updatePosition(elapsed:Float = -1)
	{
		var i:Int = 0;
		for (mod in mods)
		{
			var intendedPos:Float = (i - curSelected) * 225 + 200;
			if (i > curSelected)
				intendedPos += 225;
			mod.alphabet.y = elapsed == -1 ? intendedPos : FlxMath.lerp(intendedPos, mod.alphabet.y, Math.exp(-elapsed * 12));

			if (i == curSelected)
			{
				descriptionTxt.y = mod.alphabet.y + 160;
				for (button in buttonsArray)
					button.y = mod.alphabet.y + 320;
			}
			i++;
		}
	}

	var cornerSize:Int = 11;
	inline function makeSelectorGraphic()
	{
		inline function __draw(x:Float, y:Float, w:Float, h:Float)
		{
			selector.pixels.fillRect(new Rectangle(x, y, w, h), 0);
		}

		selector.makeGraphic(1100, 450, FlxColor.BLACK);
		__draw(0, 190, selector.width, 5);
		// selector.pixels.fillRect(new Rectangle(0, 190, selector.width, 5), 0);

		// Why did i do this? Because i'm a lmao stupid, of course
		// also i wanted to understand better how fillRect works so i did this shit lol???

		// top left
		__draw(0, 0, cornerSize, cornerSize);
		// selector.pixels.fillRect(new Rectangle(0, 0, cornerSize, cornerSize), 0);
		drawCircleCornerOnSelector(false, false);

		// top right
		__draw(selector.width - cornerSize, 0, cornerSize, cornerSize);
		// selector.pixels.fillRect(new Rectangle(selector.width - cornerSize, 0, cornerSize, cornerSize), 0);
		drawCircleCornerOnSelector(true, false);

		// bottom left
		__draw(0, selector.height - cornerSize, cornerSize, cornerSize);
		// selector.pixels.fillRect(new Rectangle(0, selector.height - cornerSize, cornerSize, cornerSize), 0);
		drawCircleCornerOnSelector(false, true);

		// bottom right
		__draw(selector.width - cornerSize, selector.height - cornerSize, cornerSize, cornerSize);
		// selector.pixels.fillRect(new Rectangle(selector.width - cornerSize, selector.height - cornerSize, cornerSize, cornerSize), 0);
		drawCircleCornerOnSelector(true, true);
	}

	function drawCircleCornerOnSelector(flipX:Bool, flipY:Bool)
	{
		inline function __drawCorner(x:Float, y:Float, w:Float, h:Float)
		{
			selector.pixels.fillRect(new Rectangle(x, Std.int(Math.abs(y)), w, h), FlxColor.BLACK);
		}

		final antiX = (selector.width - cornerSize);
		var antiY = flipY ? (selector.height - 1) : 0;

		if (flipY)
			antiY -= 2;
		__drawCorner((flipX ? antiX : 1), antiY - 8, 10, 3);
		// selector.pixels.fillRect(new Rectangle((flipX ? antiX : 1), Std.int(Math.abs(antiY - 8)), 10, 3), FlxColor.BLACK);

		if (flipY)
			antiY += 1;
		__drawCorner((flipX ? antiX : 2), antiY - 6, 9, 2);
		// selector.pixels.fillRect(new Rectangle((flipX ? antiX : 2), Std.int(Math.abs(antiY - 6)),  9, 2), FlxColor.BLACK);

		if (flipY)
			antiY += 1;
		__drawCorner((flipX ? antiX : 3), antiY - 5, 8, 1);
		__drawCorner((flipX ? antiX : 4), antiY - 4, 7, 1);
		__drawCorner((flipX ? antiX : 5), antiY - 3, 6, 1);
		__drawCorner((flipX ? antiX : 6), antiY - 2, 5, 1);
		__drawCorner((flipX ? antiX : 8), antiY - 1, 3, 1);
		/*selector.pixels.fillRect(new Rectangle((flipX ? antiX : 3), Std.int(Math.abs(antiY - 5)),  8, 1), FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 4), Std.int(Math.abs(antiY - 4)),  7, 1), FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 5), Std.int(Math.abs(antiY - 3)),  6, 1), FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 6), Std.int(Math.abs(antiY - 2)),  5, 1), FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 8), Std.int(Math.abs(antiY - 1)),  3, 1), FlxColor.BLACK);*/
	}
}

class ModMetadataClass
{
	public var folder:String;
	public var name:String;
	public var description:String = "No description provided.";
	public var color:FlxColor = ModsMenuState.defaultColor; // 0xAA00FF;
	public var restart:Bool = false; // trust me. this is very important
	public var alphabet:Alphabet;
	public var icon:AttachedSprite;

	public function new(folder:String)
	{
		this.folder = this.name = folder;

		// Try loading json
		final pack = Mods.getPack(folder);
		if (pack != null)
		{
			if (pack.name != null && pack.name.length != 0 && pack.name != "Name")
				this.name = pack.name;
			if (pack.description != null && pack.description.length != 0 && pack.description != "Description")
				this.description = pack.description;

			if (pack.color != null)
				this.color = FlxColor.fromRGB(
					pack.color[0] ?? ModsMenuState.defaultColor.red,
					pack.color[1] ?? ModsMenuState.defaultColor.green,
					pack.color[2] ?? ModsMenuState.defaultColor.blue
				);

			this.restart = pack.restart;
		}
	}
}
