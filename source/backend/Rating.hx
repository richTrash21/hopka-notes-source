package backend;

import flixel.util.FlxStringUtil;

@:structInit class Rating
{
	public static function loadDefault():Array<Rating>
	{
		return [
			{name: "sick", hitWindow: ClientPrefs.data.sickWindow}, // highest rating goes first
			{name: "good", hitWindow: ClientPrefs.data.goodWindow, ratingMod: .67, score: 200, noteSplash: false},
			{name: "bad",  hitWindow: ClientPrefs.data.badWindow,  ratingMod: .34, score: 100, noteSplash: false},
			{name: "shit", 										   ratingMod: 0,   score: 50,  noteSplash: false}
		];
	}

	public static function getRatingString(ratingsData:Array<Rating>, misses:Int):String
	{
		var s = "Clear";
		if (misses == 0)
		{
			if (ratingsData[2].hits + ratingsData[3].hits > 0) // bads and shits
				s = "FC";
			else if (ratingsData[1].hits > 0) // goods
				s = "GFC";
			else if (ratingsData[0].hits > 0) // sicks
				s = "SFC";
		}
		else if (misses < 10)
			s = "SDCB";

		return s;
	}

	public var name:String;
	public var image:String;
	public var ratingMod:Float;
	public var score:Int;
	public var noteSplash:Bool;
	public var hitWindow:Int; // ms
	public var hits = 0;

	public function new(name:String, ?image:String, ?hitWindow:Int, ratingMod = 1., score = 350, noteSplash = true)
	{
		this.name = name;
		this.image = image ?? name;
		this.hitWindow = hitWindow ?? 0;
		this.ratingMod = ratingMod;
		this.score = score;
		this.noteSplash = noteSplash;
	}

	public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("name", name),
			LabelValuePair.weak("hitWindow", hitWindow),
			LabelValuePair.weak("ratingMod", ratingMod),
			LabelValuePair.weak("score", score),
			LabelValuePair.weak("hits", hits)
		]);
	}
}
