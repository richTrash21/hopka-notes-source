package backend;

class Rating
{
	public var name:String = '';
	public var image:String = '';
	public var hitWindow:Null<Int> = 0; //ms
	public var ratingMod:Float = 1;
	public var score:Int = 350;
	public var noteSplash:Bool = true;
	public var hits:Int = 0;

	public function new(name:String)
	{
		this.name = name;
		this.image = name;
		this.hitWindow = 0;

		try { this.hitWindow = Reflect.field(backend.ClientPrefs.data, name + 'Window'); }
		catch(e) FlxG.log.error(e);
	}

	public static function loadDefault():Array<Rating>
	{
		var ratingsData:Array<Rating> = [new Rating('sick')]; //highest rating goes first

		var good:Rating = new Rating('good');
		good.ratingMod = 0.67;
		good.score = 200;
		good.noteSplash = false;
		ratingsData.push(good);

		var bad:Rating = new Rating('bad');
		bad.ratingMod = 0.34;
		bad.score = 100;
		bad.noteSplash = false;
		ratingsData.push(bad);

		var shit:Rating = new Rating('shit');
		shit.ratingMod = 0;
		shit.score = 50;
		shit.noteSplash = false;
		ratingsData.push(shit);
		return ratingsData;
	}
}
