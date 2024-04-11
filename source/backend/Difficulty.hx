package backend;

class Difficulty
{
	public static final defaultList = [
		"Easy",
		"Normal",
		"Hard"
	];
	public static var list = new Array<String>();
	public static final defaultDifficulty = "Normal"; // The chart that has no suffix and starting difficulty on Freeplay/Story Mode

	inline public static function getFilePath(?num:Int)
	{
		if (num == null)
			num = PlayState.storyDifficulty;
		return Paths.formatToSongPath(list[num] == defaultDifficulty ? "" : "-" + list[num]);
	}

	inline public static function loadFromWeek(?week:WeekData)
	{
		if (week == null)
			week = WeekData.getCurrentWeek();

		final diffStr = week.difficulties;
		if (diffStr.isNullOrEmpty())
			resetList();
		else
		{
			final diffs = diffStr.trim().split(",");
			var i = diffs.length;
			while (--i > 0)
			{
				diffs[i] = diffs[i].trim();
				if (diffs[i].length == 0)
					diffs.remove(diffs[i]);
			}

			if (diffs.length != 0 && diffs[0].length != 0)
				list = diffs;
		}
	}

	inline public static function resetList()
	{
		list = defaultList.copy();
	}

	inline public static function copyFrom(diffs:Array<String>)
	{
		list = diffs.copy();
	}

	inline public static function getString(?num:Int):String
	{
		return list[num ?? PlayState.storyDifficulty];
	}

	inline public static function getDefault():String
	{
		return defaultDifficulty;
	}
}