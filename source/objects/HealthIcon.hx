package objects;

import #if MODS_ALLOWED sys.FileSystem #else openfl.utils.Assets #end;

typedef HealthIconConfig = {scale:Float, offset:Array<Float>, antialias:Bool}

class HealthIcon extends FlxSprite
{
	public var isPlayer(default, null):Bool = false;
	public var baseScale(default, set):Float = 1; // TODO: actually find way to use baseScale (DONE!!)
	public var char(default, null):String = '';
	public var sprTracker:FlxSprite;

	function set_baseScale(Scale:Float):Float
	{
		if (baseScale == Scale) return Scale;
		return baseScale = scale.set(Scale, Scale).x;
	}

	public function new(char:String = 'bf', isPlayer:Bool = false, allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		//scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(sprTracker != null) setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, allowGPU:Bool = true)
	{
		if(this.char != char)
		{
			var prevFrame:Int = 0;
			var flip:Bool = isPlayer;
			if(animation.curAnim != null)
			{
				prevFrame = animation.curAnim.curFrame;
				flip = animation.curAnim.flipX;
			}

			var name = Paths.fileExists('images/icons/$char.png', IMAGE)
				? 'icons/$char'
				: 'icons/icon-$char'; // Older versions of psych engine's support
			if(!Paths.fileExists('images/$name.png', IMAGE))
			{
				name = 'icons/icon-face'; // Prevents crash from missing icon
				char = 'face'; // so it will create a default config for face aka. null (LMAO THATS NOT HOW IT SHOULD WORK BUT IDC) - richTrash21
			}

			final graphic = Paths.image(name, allowGPU);
			final twoFrames:Bool = graphic.width > graphic.height;
			loadGraphic(graphic, true, twoFrames ? Math.floor(graphic.width * 0.5) : graphic.width, graphic.height);
			iconOffsets = [(width - 150) * 0.5, (height - 150) * 0.5];
			updateHitbox();

			if(animation.getByName(char) == null)
				animation.add(char, twoFrames ? [0, 1] : [0], 0, false, flip);
			animation.play(char, false, false, prevFrame);
			this.char = char;
			setConfig(char);
		}
	}

	public static final defaultConfig:HealthIconConfig = {scale: 1, offset: [0, 0], antialias: true}; // for icons that don't have config
	private var configMap:Map<String, HealthIconConfig> = []; // for recycling of old jsons

	private function setConfig(char:String)
	{
		var json:HealthIconConfig = null;
		if (configMap.exists(char)) json = configMap.get(char);
		else
		{
			var rawJson:String;
			var iconPath:String = 'images/icons/$char.json';
			#if MODS_ALLOWED
			var path:String = Paths.modFolders(iconPath);
			if(!FileSystem.exists(path)) path = Paths.getPreloadPath(iconPath);

			if(!FileSystem.exists(path))
			#else
			var path:String = Paths.getPreloadPath(iconPath);
			if(!Assets.exists(path))
			#end
				rawJson = null; // no config = default config
			else
				rawJson = #if MODS_ALLOWED sys.io.File.getContent(path) #else Assets.getText(path) #end;

			json = rawJson != null ? cast haxe.Json.parse(rawJson) : defaultConfig;
			configMap.set(char, json);
		}

		// seems messy but should work just fiiine (not sure if it's optimised tho but idc its 2:30AM and im still up)
		baseScale		= #if (haxe > "4.2.5") json?.scale ?? #else json != null ? json.scale : #end 1;
		iconOffsets[0] += #if (haxe > "4.2.5") json?.offset[0] ?? #else json != null ? json.offset[0] : #end 0;
		iconOffsets[1] += #if (haxe > "4.2.5") json?.offset[1] ?? #else json != null ? json.offset[1] : #end 0;
		antialiasing	= char.endsWith('-pixel') ? false : (ClientPrefs.data.antialiasing &&
							#if (haxe > "4.2.5") (json?.antialias ?? true) #else (json != null && json.antialias) #end) == true;
	}

	override function updateHitbox()
	{
		super.updateHitbox();
		offset.set(iconOffsets[0], iconOffsets[1]);
	}

	public function getCharacter():String return char;
}
