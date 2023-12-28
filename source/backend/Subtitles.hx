package backend;

import flixel.util.FlxStringUtil;

using flixel.util.FlxArrayUtil;

/**  FlxText.hx jumpscare!!  **/
class Subtitles extends FlxText
{
	@:allow(Init)
	static var _markup:Array<FlxTextFormatMarkerPair>;

	public var lineID(get, never):Int;
	public var useMarkup:Bool = true;
	public var posY:Float = FlxG.height * 0.75;
	public var playing(get, never):Bool;

	var _parsedLines:Array<SRT>;
	var _time:Float;
	var _lineID:Int;

	public function new(?Data:String, ?Alignment:FlxTextAlign)
	{
		super(0, 0, FlxG.width * 0.8, 28);
		setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, Alignment ?? CENTER).setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		loadSubtitles(Data);
		screenCenter(X).y = posY;
		offset.y = height * 0.5;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (_parsedLines == null || _parsedLines.length == 0) // нету парснутых лайнов - идешь нахуй :3
			return; // ну а если серьезно, то это позволяет использовать субтитры как обычный текст, а затем просто загрузить в него реальные субтитры

		_time += elapsed;
		for (line in _parsedLines)
		{
			if (_time > line.end) // чистим мусор
			{
				_parsedLines.fastSplice(line);
				_parsedLines.sort(SRT.sortLines);

				if (_parsedLines.length == 0)
				{
					text = "";
					visible = true;
				}
				continue;
			}

			if (FlxMath.inBounds(_time, line.start, line.end))
			{
				if (_lineID != line.id)
				{
					_lineID = line.id;
					setText(line.text, true);
				}
				break;
			}
			else
				text = "";
		}
	}

	public function loadSubtitles(Data:String):Subtitles
	{
		_parsedLines = SRT.parseSRT(Data);
		_time = 0.0;
		_lineID = 0;
		text = "";
		trace("Parsed subtitles:\n" + _parsedLines);
		return this;
	}

	public function stopSubtitles():Subtitles
	{
		_parsedLines.clearArray();
		_time = 0.0;
		_lineID = 0;
		text = "";
		trace("Stoped subtitles!!");
		return this;
	}

	public function setText(Text:String, centerText:Bool = false):Subtitles
	{
		if (useMarkup)
			applyMarkup(Text, _markup);
		else
			text = Text;

		if (centerText)
			offset.y = height * 0.5;

		return this;
	}

	@:noCompletion inline function get_lineID():Int return _lineID;
	@:noCompletion inline function get_playing():Bool return _parsedLines != null || _parsedLines.length > 0;
}

class SRT
{
	inline public static function parseSRT(data:String, ?container:Array<SRT>):Array<SRT>
	{
		final parsedSRT:Array<SRT> = container == null ? [] : container;
		if (FlxStringUtil.isNullOrEmpty(data)) // пустой .srt - идешь нахуй :3
			return parsedSRT;

		final sepLines:Array<String> = data.split("\n");
		final tempData:Array<Array<String>> = [];
		var temp:Array<String> = null;
		// очищаем от мусора + делаем жизнь легче
		while (sepLines.contains("\r"))
		{
			if (sepLines[0] == "\r")
				sepLines.shift();

			final index:Int = sepLines.indexOf("\r");
			temp = sepLines.splice(0, index == -1 ? sepLines.length : index);
			if (temp.length > 3) // поправляем мультистрочное строение
				temp[2] = temp.splice(2, temp.length).join("");

			tempData.push(temp);
		}

		// НАКОНЕЦ ТО ПЕРЕДЕЛЫВАЕМ ЭТО ДЕРЬМО В SRT ЕПИИИИИИИ
		var section:Array<String> = null;
		var parsedTime:Array<Float> = [];
		while (tempData.length > 0)
		{
			section = tempData.pop();
			parseTimeSRT(section[1], parsedTime);
			final _id:Null<Int> = Std.parseInt(section[0].trim()); // блять, ПОЧЕМУ Std.parseInt(str) ДАЕТ null ПРИ str = "1" Я ЕБАЛ ХАКС
			parsedSRT.push(new SRT(_id ?? tempData.length+1, parsedTime.shift(), parsedTime.shift(), section[2]));
			section.clearArray();
		}
		parsedSRT.sort(sortLines);
		return parsedSRT;
	}

	inline public static function parseTimeSRT(data:String, ?container:Array<Float>):Array<Float>
	{
		final parsedTime:Array<Float> = container == null ? [] : container;
		if (FlxStringUtil.isNullOrEmpty(data))
			return parsedTime;

		final tempData:Array<String> = data.split("-->");
		while (tempData.length > 0)
		{
			final sepTime:Array<String> = tempData.pop().trim().split(":");
			parsedTime.push(CoolUtil.timeToSeconds(Std.parseFloat(sepTime.shift()), Std.parseFloat(sepTime.shift()), Std.parseFloat(sepTime.shift().replace(",", "."))));
		}
		parsedTime.reverse();
		return parsedTime;
	}

	inline public static function sortLines(Line1:SRT, Line2:SRT):Int
		return FlxMath.numericComparison(Line1.id, Line2.id);

	public var id:Int;
	public var start:Float;
	public var end:Float;
	public var text:String;

	public function new(id:Int, start:Float, end:Float, text:String)
	{
		this.id = id;
		this.start = start;
		this.end = end;
		this.text = text;
	}

	public function toString():String
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("id", id),
			LabelValuePair.weak("time", [start, end]),
			LabelValuePair.weak("text", text)
		]);
}
