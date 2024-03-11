package backend;

@:structInit class Rating
{
	public var name:String = "";
	public var image:String = "";
	public var ratingMod:Float = 1;
	public var score:Int = 350;
	public var noteSplash:Bool = true;
	public var hitWindow:Int = 0; // ms
	public var hits = 0;

	/*public function new(name:String, ?image:String, ?hitWindow:Int, ratingMod = 1., score = 350, noteSplash = true)
	{
		this.name = name;
		this.image = image ?? name;
		this.hitWindow = hitWindow ?? 0; // (Reflect.field(ClientPrefs.data, name + "Window") ?? 0);
		this.ratingMod = ratingMod;
		this.score = score;
		this.noteSplash = noteSplash;
	}*/

	public static function loadDefault():Array<Rating>
	{
		return [
			{name: "sick", image: "sick", hitWindow: ClientPrefs.data.sickWindow}, // highest rating goes first
			{name: "good", image: "good", hitWindow: ClientPrefs.data.goodWindow, ratingMod: .67, score: 200, noteSplash: false},
			{name: "bad",  image: "bad",  hitWindow: ClientPrefs.data.badWindow,  ratingMod: .34, score: 100, noteSplash: false},
			{name: "shit", image: "shit", hitWindow: 0,							  ratingMod: 0,   score: 50,  noteSplash: false}
		];
	}
}
