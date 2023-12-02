package objects;

import flixel.math.FlxPoint;
import #if MODS_ALLOWED sys.FileSystem #else openfl.utils.Assets #end;

typedef HealthIconConfig = {?scale:Float, ?offset:Array<Float>, ?antialias:Bool, ?flip_x:Bool}

class HealthIcon extends ExtendedSprite
{
	public var isPlayer(default, null):Bool = false;
	public var baseScale(default, set):Float = 1;
	public var char(default, null):String = null;
	public var sprTracker:FlxSprite;

	public var lerpScale:Bool = false;
	public var lerpSpeed:Float = 1.0;
	var _speed:Float = 9.0;
	@:isVar public static var globalSpeed(get, set):Float = 1.0;

	inline function set_baseScale(Scale:Float):Float
		return (baseScale == Scale ? Scale : baseScale = setScale(Scale).x);

	public function new(char:String = 'bf', isPlayer:Bool = false, allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		//scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		if (lerpScale)
		{
			setScale(FlxMath.lerp(baseScale, scale.x, Math.max(1 - (_speed * elapsed * lerpSpeed * globalSpeed), 0)));
			updateHitbox();
		}

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - height * 0.25);
		
		super.update(elapsed);
	}

	public var iconOffsets:FlxPoint = FlxPoint.get();
	public function changeIcon(char:String, allowGPU:Bool = true)
	{
		if (this.char != char)
		{
			var prevFrame:Int = 0;
			var flip:Bool = isPlayer;
			if (animation.curAnim != null)
			{
				prevFrame = animation.curAnim.curFrame;
				flip = animation.curAnim.flipX;
			}

			var name = Paths.fileExists('images/icons/$char.png', IMAGE) ? 'icons/$char' : 'icons/icon-$char'; // Older versions of psych engine's support
			if (!Paths.fileExists('images/$name.png', IMAGE))
			{
				name = 'icons/icon-face'; // Prevents crash from missing icon
				char = 'face'; // so it will create a default config for face aka. null (LMAO THATS NOT HOW IT SHOULD WORK BUT IDC) - richTrash21
			}

			final json:HealthIconConfig = getConfig(char);
			final graphic = Paths.image(name, allowGPU);
			loadGraphic(graphic, true, (graphic.width > graphic.height) ? Math.floor(graphic.width * 0.5) : graphic.width, graphic.height);

			iconOffsets.copyFrom(animOffsets.exists(char) ? animOffsets.get(char) : addOffset(char, (width - 150) * 0.5, (height - 150) * 0.5));
			if (json.offset != null && json.offset.length > 1) iconOffsets.add(json.offset[0], json.offset[1]);

			// seems messy but should work just fiiine (not sure if it's optimised tho but idc its 2:30AM and im still up)
			flipX	  = json.flip_x ?? false;
			baseScale = json.scale ?? 1;
			updateHitbox();

			final _antialias:Bool = ClientPrefs.data.antialiasing ? json.antialias ?? true : false;
			antialiasing = char.endsWith('-pixel') ? false : _antialias;

			if (!animExists(char))
				addAnim(char, [for (i in 0...numFrames) i], 0, false, flip);
			playAnim(char, false, prevFrame);
			this.char = char;
		}
	}

	// for icons that don't have config
	private static final defaultConfig:HealthIconConfig = {scale: 1, offset: [0, 0], flip_x: false};

	inline public static function getConfig(char:String):HealthIconConfig
	{
		final iconPath:String = 'images/icons/$char.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(iconPath);
		if (!FileSystem.exists(path)) path = Paths.getPreloadPath(iconPath);
		if (FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(iconPath);
		if (Assets.exists(path))
		#end
		{
			final rawJson:String = #if MODS_ALLOWED sys.io.File.getContent(path) #else Assets.getText(path) #end;
			return cast haxe.Json.parse(rawJson);
		}
		return defaultConfig; // so if json couldn't be found default would be used instead
	}

	override function updateHitbox()
	{
		super.updateHitbox();
		offset.copyFrom(iconOffsets);
	}

	override function destroy()
	{
		super.destroy();
		iconOffsets = flixel.util.FlxDestroyUtil.put(iconOffsets);
	}

	public function getCharacter():String return char;

	@:noCompletion inline static function get_globalSpeed():Float
		return (PlayState.instance != null ? PlayState.instance.playbackRate : globalSpeed);

	@:noCompletion inline static function set_globalSpeed(speed:Float):Float
		return (PlayState.instance != null ? PlayState.instance.playbackRate : globalSpeed = speed); // won't allow to set variable if camera placed in PlayState
}
