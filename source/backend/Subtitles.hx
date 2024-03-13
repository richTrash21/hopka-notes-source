package backend;

import flixel.util.FlxStringUtil;

using flixel.util.FlxArrayUtil;

/**  FlxText.hx jumpscare!!  **/
class Subtitles extends FlxText
{
	@:allow(Init)
	static var _markup = new Array<FlxTextFormatMarkerPair>();
	@:allow(Init)
	static var __posY = 0.;

	public var lineID(default, null):Int;
	public var playing(get, never):Bool;
	public var useMarkup:Bool = true;

	var _parsedLines:Array<SRTData>;
	var _time:Float;

	public function new(?data:String, ?alignment:FlxTextAlign)
	{
		super(0, 0, FlxG.width * 0.8, 28);
		font = Paths.font("vcr.ttf");
		this.alignment = alignment ?? CENTER;
		setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		loadSubtitles(data).screenCenter(X).y = FlxG.height * 0.75;
		offset.y = height * 0.5;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (_parsedLines?.length == 0) // нету парснутых лайнов - идешь нахуй :3
			return; // ну а если серьезно, то это позволяет использовать субтитры как обычный текст, а затем просто загрузить в него реальные субтитры

		_time += elapsed;
		for (line in _parsedLines)
		{
			if (_time > line.end) // чистим мусор
			{
				_parsedLines.fastSplice(line).sort(SRTData.sortLines);
				if (_parsedLines.length == 0)
				{
					text = "";
					visible = true;
				}
				continue;
			}

			if (FlxMath.inBounds(_time, line.start, line.end))
			{
				if (lineID != line.id)
				{
					lineID = line.id;
					setText(line.text, true);
				}
				break;
			}
			else
				text = "";
		}
	}

	public function loadSubtitles(data:String):Subtitles
	{
		_parsedLines = SRTData.parseSRT(data);
		_time = 0.0;
		lineID = 0;
		text = "";
		trace('Parsed subtitles:\n$_parsedLines');
		return this;
	}

	public function stopSubtitles():Subtitles
	{
		_parsedLines.clearArray();
		_time = 0.0;
		lineID = 0;
		text = "";
		trace("Stoped subtitles!!");
		return this;
	}

	public function setText(text:String, centerText = false):Subtitles
	{
		if (useMarkup)
			applyMarkup(text, _markup);
		else
			this.text = text;

		if (centerText)
			offset.y = height * 0.5;

		return this;
	}

	@:noCompletion inline function get_playing():Bool
	{
		return _parsedLines?.length > 0;
	}
}

@:structInit class SRTData
{
	/*inline*/ public static function parseSRT(data:String, ?container:Array<SRTData>):Array<SRTData>
	{
		if (container == null)
			container = [];

		if (FlxStringUtil.isNullOrEmpty(data)) // пустой .srt - идешь нахуй :3
			return container;

		var temp:Array<String>;
		final sepLines = data.split("\n");
		final tempData = new Array<Array<String>>();
		// очищаем от мусора + делаем жизнь легче
		while (sepLines.contains("\r"))
		{
			if (sepLines[0] == "\r")
				sepLines.shift();

			final index = sepLines.indexOf("\r");
			temp = sepLines.splice(0, index == -1 ? sepLines.length : index);
			if (temp.length > 3) // поправляем мультистрочное строение
				temp[2] = temp.splice(2, temp.length).join("");

			tempData.push(temp);
		}

		// НАКОНЕЦ ТО ПЕРЕДЕЛЫВАЕМ ЭТО ДЕРЬМО В SRT ЕПИИИИИИИ
		var section:Array<String>;
		var parsedTime = new Array<Float>();
		while (tempData.length > 0)
		{
			section = tempData.pop();
			parseTimeSRT(section[1], parsedTime);
			container.push(
			{
				id:    Std.parseInt(section[0]) ?? tempData.length+1, // блять, ПОЧЕМУ Std.parseInt(str) ДАЕТ null ПРИ str = "1" Я ЕБАЛ ХАКС
				start: parsedTime[0],
				end:   parsedTime[1],
				text:  section[2]
			});

			parsedTime.clearArray();
			section.clearArray();
		}
		container.sort(sortLines);
		return container;
	}

	/*inline*/ public static function parseTimeSRT(data:String, ?container:Array<Float>):Array<Float>
	{
		if (container == null)
			container = [];

		if (FlxStringUtil.isNullOrEmpty(data))
			return container;

		var sepTime:Array<String>;
		final tempData = data.split("-->");
		while (tempData.length > 0)
		{
			sepTime = tempData.pop().split(":");
			container.push(CoolUtil.timeToSeconds(Std.parseFloat(sepTime[0]), Std.parseFloat(sepTime[1]), Std.parseFloat(sepTime[2].replace(",", "."))));
		}
		container.reverse();
		return container;
	}

	inline public static function sortLines(line1:SRTData, line2:SRTData):Int
	{
		return line2.id > line1.id ? -1 : (line1.id > line2.id ? 1 : 0); // FlxMath.numericComparison(line1.id, line2.id);
	}

	public var id:Int;
	public var start:Float;
	public var end:Float;
	public var text:String;

	public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("id", id),
			LabelValuePair.weak("time", [start, end]),
			LabelValuePair.weak("text", text)
		]);
	}
}
