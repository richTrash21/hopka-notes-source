package objects;

import flixel.math.FlxPoint;
import #if MODS_ALLOWED sys.FileSystem #else openfl.utils.Assets #end;

typedef HealthIconConfig = {?scale:Float, ?offset:Array<Float>, ?antialias:Bool, ?flip_x:Bool}

class HealthIcon extends ExtendedSprite
{
	inline public static final ICON_WIDTH = 150.;
	inline public static final ICON_HEIGHT = 150.;

	// for icons that don't have config
	static final defaultConfig:HealthIconConfig = {scale: 1, offset: [0, 0], antialias: true, flip_x: false};
	public static final jsonCache = new Map<String, HealthIconConfig>();

	 public static function getConfig(char:String, ?useCache = true):HealthIconConfig
	{
		if (useCache && jsonCache.exists(char))
			return jsonCache.get(char);

		var config = defaultConfig; // so if json couldn't be found default would be used instead
		var path:String;
		final iconPath = 'images/icons/$char.json';
		#if MODS_ALLOWED
		path = Paths.modFolders(iconPath);
		if (!FileSystem.exists(path))
			path = Paths.getPreloadPath(iconPath);

		if (FileSystem.exists(path))
		#else
		path = Paths.getPreloadPath(iconPath);
		if (Assets.exists(path))
		#end
			config = cast haxe.Json.parse(#if MODS_ALLOWED sys.io.File.getContent(path) #else Assets.getText(path) #end);

		if (useCache)
			jsonCache.set(char, config);

		return config;
	}

	public var isPlayer(default, null):Bool = false;
	public var baseScale(default, set):Float = 1;
	public var char(default, null):String = null;

	public var sprTracker:FlxSprite;
	public var copyX:Bool = true;
	public var copyY:Bool = true;

	public var lerpScale:Bool = false;
	public var lerpSpeed:Float = 1.0;

	var _speed = 9.0;

	public function new(char = "bf", isPlayer = false, allowGPU = true, ?useCache = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU, useCache);
	}

	override function update(elapsed:Float)
	{
		if (lerpScale && scale.x != baseScale /*&& isOnScreen(camera)*/)
		{
			setScale(FlxMath.lerp(baseScale, scale.x, Math.exp(-elapsed * _speed * lerpSpeed))); // Math.max(1 - (_speed * elapsed * lerpSpeed), 0)
			updateHitbox();
		}

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + width * 0.15, sprTracker.y - height * 0.25);
		
		super.update(elapsed);
	}

	public function changeIcon(char:String, allowGPU = true, ?useCache = true)
	{
		if (this.char == char)
			return;

		final prevFrame = animation.curAnim?.curFrame ?? 0;
		final flip = animation.curAnim?.flipX ?? isPlayer;

		var name = Paths.fileExists('images/icons/$char.png', IMAGE) ? 'icons/$char' : 'icons/icon-$char'; // Older versions of psych engine's support
		if (!Paths.fileExists('images/$name.png', IMAGE))
		{
			name = "icons/icon-face"; // Prevents crash from missing icon
			char = "face"; // so it will create a default config for face aka. null (LMAO THATS NOT HOW IT SHOULD WORK BUT IDC) - richTrash21
		}

		final json = getConfig(char, useCache);
		final graphic = Paths.image(name, allowGPU);
		loadGraphic(graphic, true, (graphic.width > graphic.height) ? Math.floor(graphic.width * 0.5) : graphic.width, graphic.height);

		if (!animOffsets.exists(char))
		{
			final o = addOffset(char, (width - ICON_WIDTH) * 0.5, (height - ICON_HEIGHT) * 0.5);
			if (json.offset?.length > 1)
				o.add(json.offset[0], json.offset[1]);
		}

		// seems messy but should work just fiiine (not sure if it's optimised tho but idc its 2:30AM and im still up)
		flipX	  = json.flip_x ?? false;
		baseScale = json.scale ?? 1;
		updateHitbox();
		// offset.set();

		antialiasing = char.endsWith("-pixel") ? false : (ClientPrefs.data.antialiasing && json.antialias);

		if (!animExists(char))
			addAnim(char, [for (i in 0...numFrames) i], 0, false, flip);

		playAnim(char, false, prevFrame);
		this.char = char;
	}

	override function updateHitbox()
	{
		width = ICON_WIDTH + Math.abs(scale.x - baseScale) * frameWidth;
		height = ICON_HEIGHT + Math.abs(scale.y - baseScale) * frameHeight;
		centerOrigin();
	}

	override function destroy()
	{
		sprTracker = null;
		super.destroy();
	}

	@:noCompletion inline function set_baseScale(scale:Float):Float
	{
		return baseScale = setScale(scale).x;
	}
}
