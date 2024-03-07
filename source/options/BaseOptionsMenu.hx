package options;

import flixel.util.FlxDestroyUtil;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.display.FlxBackdrop;

import objects.CheckboxThingie;
import objects.AttachedText;
import options.Option;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	public function new()
	{
		super();

		if (title == null)
			title = "Options";
		if (rpcTitle == null)
			rpcTitle = "Options Menu";
		
		#if desktop
		DiscordClient.changePresence(rpcTitle, null);
		#end
		
		/*final bg:ExtendedSprite = new ExtendedSprite("menuDesat");
		bg.color = 0xFFea71fd;
		bg.active = false;
		add(bg.screenCenter());*/

		final grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		grid.alpha = 0;
		FlxTween.num(0, 1, 0.5, {ease: FlxEase.quadOut}, (a) -> grid.alpha = a);
		add(grid);

		// avoids lagspikes while scrolling through menus!
		add(grpOptions	  = new FlxTypedGroup<Alphabet>());
		add(grpTexts	  = new FlxTypedGroup<AttachedText>());
		add(checkboxGroup = new FlxTypedGroup<CheckboxThingie>());
		add(descBox		  = new FlxSprite().makeGraphic(1, 1, 0x99000000));

		final titleText:Alphabet = new Alphabet(75, 45, title, true);
		titleText.setScale(0.6);
		titleText.alpha = 0.4;
		add(titleText);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		for (i in 0...optionsArray.length)
		{
			final optionText:Alphabet = new Alphabet(290, 260, optionsArray[i].name, false);
			optionText.isMenuItem = true;
			/*optionText.forceX = 300;
			optionText.yMult = 90;*/
			optionText.targetY = i;
			grpOptions.add(optionText);

			if (optionsArray[i].type == "bool")
			{
				final checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].value == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
			}
			else
			{
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
				//optionText.xAdd -= 80;
				final valueText:AttachedText = new AttachedText("" + optionsArray[i].value, optionText.width + 60);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			//optionText.snapToPosition(); //Don't ignore me when i ask for not making a fucking pull request to uncomment this line ok
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();
	}

	public function addOption(option:Option)
	{
		if (optionsArray == null)
			optionsArray = [];
		optionsArray.push(option);
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	override function update(elapsed:Float)
	{
		final MOUSE = FlxG.mouse.wheel != 0;
		final UP = controls.UI_UP_P;
		if (MOUSE || (UP || controls.UI_DOWN_P))
			changeSelection(MOUSE ? -FlxG.mouse.wheel : (UP ? -1 : 1));

		if (controls.BACK)
		{
			close();
			FlxG.sound.play(Paths.sound("cancelMenu"));
		}

		if (nextAccept <= 0)
		{
			if (curOption.type == "bool")
			{
				if (controls.ACCEPT)
				{
					FlxG.sound.play(Paths.sound("scrollMenu"));
					curOption.value = (curOption.value == true) ? false : true;
					curOption.change();
					reloadCheckboxes();
				}
			}
			else
			{
				final LEFT = controls.UI_LEFT;
				final LEFT_P = controls.UI_LEFT_P;
				if (LEFT || controls.UI_RIGHT)
				{
					final pressed = (LEFT_P || controls.UI_RIGHT_P);
					if (holdTime > 0.5 || pressed)
					{
						if (pressed)
						{
							switch(curOption.type)
							{
								case "int" | "float" | "percent":
									holdValue = FlxMath.bound(curOption.value + (LEFT ? -curOption.changeValue : curOption.changeValue), curOption.minValue, curOption.maxValue);
									switch(curOption.type)
									{
										case "int":					holdValue = Math.round(holdValue);
										case "float" | "percent":	holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
									}
									curOption.value = holdValue;

								case "string":
									final num = FlxMath.wrap(curOption.curOption + (LEFT_P ? -1 : 1), 0, curOption.options.length-1); //lol
									curOption.curOption = num;
									curOption.value = curOption.options[num]; //lol
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.sound("scrollMenu"));
						}
						else if (curOption.type != "string")
						{
							holdValue = FlxMath.bound(holdValue + curOption.scrollSpeed * elapsed * (LEFT ? -1 : 1), curOption.minValue, curOption.maxValue);
							switch(curOption.type)
							{
								case "int":					curOption.value = Math.round(holdValue);
								case "float" | "percent":	curOption.value = FlxMath.roundDecimal(holdValue, curOption.decimals);
							}
							updateTextFrom(curOption);
							curOption.change();
						}
					}

					if (curOption.type != "string")
						holdTime += elapsed;
				}
				else if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
					clearHold();
			}

			if (controls.RESET)
			{
				final leOption:Option = optionsArray[curSelected];
				leOption.value = leOption.defaultValue;
				if (leOption.type != "bool")
				{
					if (leOption.type == "string")
						leOption.curOption = leOption.options.indexOf(leOption.value);
					updateTextFrom(leOption);
				}
				leOption.change();
				FlxG.sound.play(Paths.sound("cancelMenu"));
				reloadCheckboxes();
			}
		}

		if (nextAccept > 0)
			--nextAccept;
		super.update(elapsed);
	}

	override function destroy()
	{
		while (optionsArray.length > 0)
			FlxDestroyUtil.destroy(optionsArray.pop());

		optionsArray = null;
		curOption = FlxDestroyUtil.destroy(curOption);
		grpOptions = FlxDestroyUtil.destroy(grpOptions);
		checkboxGroup = FlxDestroyUtil.destroy(checkboxGroup);
		grpTexts = FlxDestroyUtil.destroy(grpTexts);
		descBox = FlxDestroyUtil.destroy(descBox);
		descText = FlxDestroyUtil.destroy(descText);
		super.destroy();
	}

	function updateTextFrom(option:Option)
	{
		var val:Dynamic = option.value;
		if (option.type == "percent")
			val *= 100;
		option.text = option.displayFormat.replace("%v", val).replace("%d", option.defaultValue);
	}

	function clearHold()
	{
		if (holdTime > 0.5)
			FlxG.sound.play(Paths.sound("scrollMenu"));
		holdTime = 0;
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionsArray.length-1);

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;

		var bullShit = 0;
		for (item in grpOptions.members)
		{
			item.targetY = bullShit++ - curSelected;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}
		for (text in grpTexts)
			text.alpha = text.ID == curSelected ? 1 : 0.6;

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(descText.width + 20, descText.height + 25);
		descBox.updateHitbox();

		curOption = optionsArray[curSelected]; //shorter lol
		FlxG.sound.play(Paths.sound("scrollMenu"));
	}

	function reloadCheckboxes()
	{
		for (checkbox in checkboxGroup)
			checkbox.daValue = (optionsArray[checkbox.ID].value == true);
	}
}