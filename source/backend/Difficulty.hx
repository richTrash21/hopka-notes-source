package backend;

class Difficulty
{
	public static final defaultList:Array<String> = [
		'Easy',
		'Normal',
		'Hard'
	];
	public static var list:Array<String> = [];
	private static final defaultDifficulty:String = 'Normal'; //The chart that has no suffix and starting difficulty on Freeplay/Story Mode

	inline public static function getFilePath(?num:Int)
	{
		if (num == null) num = PlayState.storyDifficulty;
		return Paths.formatToSongPath(list[num] == defaultDifficulty ? '' : '-${list[num]}');
	}

	inline public static function loadFromWeek(?week:WeekData)
	{
		if (week == null) week = WeekData.getCurrentWeek();

		final diffStr:String = week.difficulties;
		if (diffStr != null && diffStr.length > 0)
		{
			final diffs:Array<String> = diffStr.trim().split(',');
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				final _diff:String = diffs[i];
				if (_diff != null)
				{
					diffs[i] = _diff.trim();
					if (_diff.length == 0) diffs.remove(_diff);
				}
				--i;
			}

			if (diffs.length > 0 && diffs[0].length > 0)
				list = diffs;
		}
		else resetList();
	}

	inline public static function resetList()					list = defaultList.copy();
	inline public static function copyFrom(diffs:Array<String>)	list = diffs.copy();
	inline public static function getString(?num:Int):String	return list[num ?? PlayState.storyDifficulty];
	inline public static function getDefault():String			return defaultDifficulty;
}