package substates;

import objects.AttachedText;
import objects.CheckboxThingie;

class GameplayChangersSubstate extends MusicBeatSubstate
{
	private var curOption:GameplayOption;
	private var curSelected:Int = 0;
	private var optionsArray:Array<GameplayOption> = [];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	public function getOptionByName(name:String):GameplayOption
	{
		for (opt in optionsArray)
			if (opt.name == name)
				return opt;

		return null;
	}

	public function new()
	{
		super(0);
		FlxTween.num(0, 0.6, 0.2, (a) -> { bgColor.alphaFloat = a; if (FlxG.renderTile) bgColor = bgColor; });

		// avoids lagspikes while scrolling through menus!
		add(grpOptions	  = new FlxTypedGroup<Alphabet>());
		add(grpTexts	  = new FlxTypedGroup<AttachedText>());
		add(checkboxGroup = new FlxTypedGroup<CheckboxThingie>());
		
		final goption:GameplayOption = new GameplayOption('Scroll Type', 'scrolltype', 'string', 'multiplicative', ["multiplicative", "constant"]);
		optionsArray.push(new GameplayOption('Scroll Type', 'scrolltype', 'string', 'multiplicative', ["multiplicative", "constant"]));

		final option:GameplayOption = new GameplayOption('Scroll Speed', 'scrollspeed', 'float', 1);
		option.scrollSpeed = 2.0;
		option.minValue = 0.35;
		option.changeValue = 0.05;
		option.decimals = 2;
		if (goption.value != "constant")
		{
			option.displayFormat = '%vX';
			option.maxValue = 3;
		}
		else
		{
			option.displayFormat = "%v";
			option.maxValue = 6;
		}
		optionsArray.push(option);

		#if FLX_PITCH
		final option:GameplayOption = new GameplayOption('Playback Rate', 'songspeed', 'float', 1);
		option.scrollSpeed = 1;
		option.minValue = 0.5;
		option.maxValue = 3.0;
		option.changeValue = 0.05;
		option.displayFormat = '%vX';
		option.decimals = 2;
		optionsArray.push(option);
		#end

		final option:GameplayOption = new GameplayOption('Health Gain Multiplier', 'healthgain', 'float', 1);
		option.scrollSpeed = 2.5;
		option.minValue = 0;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		final option:GameplayOption = new GameplayOption('Health Loss Multiplier', 'healthloss', 'float', 1);
		option.scrollSpeed = 2.5;
		option.minValue = 0.5;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		optionsArray.push(new GameplayOption('Instakill on Miss', 'instakill', 'bool', false));
		optionsArray.push(new GameplayOption('Practice Mode', 'practice', 'bool', false));
		optionsArray.push(new GameplayOption('Botplay', 'botplay', 'bool', false));
		optionsArray.push(new GameplayOption('Showcase Mode', 'showcase', 'bool', false));

		for (i in 0...optionsArray.length)
		{
			final optionText:Alphabet = new Alphabet(200, 360, optionsArray[i].name, true);
			optionText.isMenuItem = true;
			optionText.setScale(0.8);
			optionText.targetY = i;
			optionText.scrollFactor.set();
			grpOptions.add(optionText);

			if (optionsArray[i].type == 'bool')
			{
				optionText.x += 90;
				optionText.startPosition.x += 90;
				optionText.snapToPosition();
				final checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].value == true);
				checkbox.sprTracker = optionText;
				checkbox.offsetX -= 20;
				checkbox.offsetY = -52;
				checkbox.ID = i;
				checkbox.scrollFactor.set();
				checkboxGroup.add(checkbox);
			}
			else
			{
				optionText.snapToPosition();
				final valueText:AttachedText = new AttachedText(Std.string(optionsArray[i].value), optionText.width + 40, 0, true, 0.8);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				valueText.scrollFactor.set();
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P || controls.UI_DOWN_P)
			changeSelection(controls.UI_UP_P ? -1 : 1);

		if (controls.BACK)
		{
			close();
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if (nextAccept <= 0)
		{
			if (curOption.type == 'bool')
			{
				if (controls.ACCEPT)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					curOption.value = (curOption.value == true) ? false : true;
					curOption.change();
					reloadCheckboxes();
				}
			}
			else
			{
				if (controls.UI_LEFT || controls.UI_RIGHT)
				{
					final pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
					if (holdTime > 0.5 || pressed)
					{
						if (pressed)
						{
							switch(curOption.type)
							{
								case 'int' | 'float' | 'percent':
									holdValue = FlxMath.bound(curOption.value + (controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue), curOption.minValue, curOption.maxValue);
									switch(curOption.type)
									{
										case 'int':				  holdValue = Math.round(holdValue);
										case 'float' | 'percent': holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
									}
									curOption.value = holdValue;

								case 'string':
									final num:Int = FlxMath.wrap(curOption.curOption + (controls.UI_LEFT_P ? -1 : 1), 0, curOption.options.length - 1); //lol
									curOption.curOption = num;
									curOption.value = curOption.options[num]; //lol
									
									if (curOption.name == "Scroll Type")
									{
										final oOption:GameplayOption = getOptionByName("Scroll Speed");
										if (oOption != null)
										{
											if (curOption.value == "constant")
											{
												oOption.displayFormat = "%v";
												oOption.maxValue = 6;
											}
											else
											{
												oOption.displayFormat = "%vX";
												oOption.maxValue = 3;
												if (oOption.value > 3) oOption.value = 3;
											}
											updateTextFrom(oOption);
										}
									}
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.sound('scrollMenu'));
						}
						else if (curOption.type != 'string')
						{
							holdValue = Math.max(curOption.minValue, Math.min(curOption.maxValue, holdValue + curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1)));

							switch(curOption.type)
							{
								case 'int':
									curOption.value = Math.round(holdValue);
								
								case 'float' | 'percent':
									final blah:Float = Math.max(curOption.minValue, Math.min(curOption.maxValue, holdValue + curOption.changeValue - (holdValue % curOption.changeValue)));
									curOption.value = FlxMath.roundDecimal(blah, curOption.decimals);
							}
							updateTextFrom(curOption);
							curOption.change();
						}
					}

					if (curOption.type != 'string') holdTime += elapsed;
				}
				else if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
					clearHold();
			}

			if (controls.RESET)
			{
				for (i in 0...optionsArray.length)
				{
					final leOption:GameplayOption = optionsArray[i];
					leOption.value = leOption.defaultValue;
					if (leOption.type != 'bool')
					{
						if (leOption.type == 'string')
							leOption.curOption = leOption.options.indexOf(leOption.value);

						updateTextFrom(leOption);
					}

					if (leOption.name == 'Scroll Speed')
					{
						leOption.displayFormat = "%vX";
						leOption.maxValue = 3;
						if (leOption.value > 3)
							leOption.value = 3;

						updateTextFrom(leOption);
					}
					leOption.change();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if (nextAccept > 0)
			nextAccept -= 1;

		super.update(elapsed);
	}

	function updateTextFrom(option:GameplayOption)
	{
		var val:Dynamic = option.value;
		if (option.type == 'percent')
			val *= 100;
		option.text = option.displayFormat.replace('%v', val).replace('%d',  option.defaultValue);
	}

	function clearHold()
	{
		if (holdTime > 0.5)
			FlxG.sound.play(Paths.sound('scrollMenu'));
		holdTime = 0;
	}

	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionsArray.length-1);

		var bullShit:Int = 0;
		for (item in grpOptions.members)
		{
			item.targetY = bullShit++ - curSelected;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}
		for (text in grpTexts)
			text.alpha = text.ID == curSelected ? 1 : 0.6;

		curOption = optionsArray[curSelected]; //shorter lol
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function reloadCheckboxes()
	{
		for (checkbox in checkboxGroup)
			checkbox.daValue = (optionsArray[checkbox.ID].value == true);
	}
}

class GameplayOption
{
	public var child:Alphabet;
	public var text(get, set):String;
	public var onChange:()->Void;					// Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = 'bool';	// bool, int (or integer), float (or fl), percent, string (or str)
													// Bool will use checkboxes
													// Everything else will use a text

	public var showBoyfriend:Bool;
	public var scrollSpeed:Float = 50;				// Only works on int/float, defines how fast it scrolls per second while holding left/right

	private var variable:String;					// Variable from ClientPrefs.hx's gameplaySettings
	public var defaultValue:Dynamic;

	public var curOption:Int = 0;					// Don't change this
	public var options:Array<String>;				// Only used in string type
	public var changeValue:Dynamic = 1;				// Only used in int/float/percent type, how much is changed when you PRESS
	public var minValue:Dynamic;					// Only used in int/float/percent type
	public var maxValue:Dynamic;					// Only used in int/float/percent type
	public var decimals:Int = 1;					// Only used in float/percent type

	public var displayFormat:String = '%v';			// How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var name:String = 'Unknown';

	public var value(get, set):Dynamic;

	public function new(name:String, variable:String, type:String = 'bool', defaultValue:Dynamic = 'null variable value', ?options:Array<String>)
	{
		this.name = name;
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;

		if (defaultValue == 'null variable value')
		{
			switch(type)
			{
				case 'bool':		  defaultValue = false;
				case 'int' | 'float': defaultValue = 0;
				case 'percent':		  defaultValue = 1;
				case 'string':		  defaultValue = (options.length > 0) ? options[0] : '';
			}
		}

		if (value == null) value = defaultValue;

		switch(type)
		{
			case 'string':
				final num:Int = options.indexOf(value);
				if (num > -1) curOption = num;
	
			case 'percent':
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
		}
	}

	public function change() //nothing lol
		if (onChange != null) onChange();

	public function get_value():Dynamic
		return ClientPrefs.data.gameplaySettings.get(variable);

	public function set_value(val:Dynamic)
	{
		ClientPrefs.data.gameplaySettings.set(variable, val);
		return val;
	}

	private function get_text():String
		return child?.text;

	private function set_text(newValue:String = ''):String
		return child == null ? null : child.text = newValue;

	private function get_type()
	{
		return type = switch (type.toLowerCase().trim())
		{
			case 'int' | 'float' | 'percent' | 'string': type;
			case 'integer':	'int';
			case 'str':		'string';
			case 'fl':		'float';
			default:		'bool';
		}
	}
}