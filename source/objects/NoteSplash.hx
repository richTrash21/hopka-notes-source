package objects;

import shaders.RGBPalette;
import shaders.PixelSplashShader.PixelSplashShaderRef;

typedef NoteSplashConfig = {
	anim:String,
	minFps:Int,
	maxFps:Int,
	offsets:Array<Array<Float>>
}

class NoteSplash extends FlxSprite implements ISortable
{
	public var rgbShader:PixelSplashShaderRef;
	var _textureLoaded:String = null;
	var _configLoaded:String = null;

	inline public static final defaultNoteSplash:String = "noteSplashes/noteSplashes";
	public static var configs:Map<String, NoteSplashConfig> = [];

	public var order:Int = 0;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		final songSkin = PlayState.SONG.splashSkin;
		final skin = (songSkin?.length > 0) ? songSkin : defaultNoteSplash + getSplashSkinPostfix();
		
		rgbShader = new PixelSplashShaderRef();
		shader = rgbShader.shader;
		precacheConfig(skin);
		_configLoaded = skin;
		// scrollFactor.set();
	}

	/*override function destroy()
	{
		configs.clear();
		super.destroy();
	}*/

	var maxAnims:Int = 2;
	public function setupNoteSplash(x:Float, y:Float, direction:Int = 0, ?note:Note)
	{
		setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
		aliveTime = 0;

		final songSkin = PlayState.SONG.splashSkin;
		final texture = if (note?.noteSplashData.texture != null)
							note.noteSplashData.texture;
						else if (songSkin?.length > 0)
							songSkin;
						else
							defaultNoteSplash + getSplashSkinPostfix();
		// rich: i hate how note splashes work
		// trace('texture to load - "$texture"');
		
		final config = _textureLoaded == texture ? precacheConfig(_configLoaded) : loadAnims(texture);

		var tempShader:RGBPalette = null;
		if ((note == null || note.noteSplashData.useRGBShader) && (PlayState.SONG == null || !PlayState.SONG.disableNoteRGB))
		{
			// If Note RGB is enabled:
			if (#if (haxe > "4.2.5") !note?.noteSplashData.useGlobalShader #else note != null && !note.noteSplashData.useGlobalShader #end)
			{
				if (note.noteSplashData.r != -1)
					note.rgbShader.r = note.noteSplashData.r;
				if (note.noteSplashData.g != -1)
					note.rgbShader.g = note.noteSplashData.g;
				if (note.noteSplashData.b != -1)
					note.rgbShader.b = note.noteSplashData.b;

				tempShader = note.rgbShader.parent;
			}
			else
				tempShader = Note.globalRgbShaders[direction];
		}

		alpha = #if (haxe > "4.2.5") note?.noteSplashData.a ?? #else note != null ? note.noteSplashData.a : #end ClientPrefs.data.splashAlpha;
		rgbShader.copyValues(tempShader);

		if (PlayState.isPixelStage || !ClientPrefs.data.antialiasing)
			antialiasing = false;
		else if (note != null)
			antialiasing = note.noteSplashData.antialiasing;

		_textureLoaded = texture;
		offset.set(10, 10);

		final animNum = FlxG.random.int(1, maxAnims);
		animation.play('note$direction-$animNum', true);
		animation.finishCallback = (_) -> kill();
		
		var minFps = 22;
		var maxFps = 26;
		if (config == null)
			offset.subtract(58, 55);
		else
		{
			final animID = direction + ((animNum - 1) * Note.colArray.length);
			final offs:Array<Float> = config.offsets[FlxMath.wrap(animID, 0, config.offsets.length-1)];
			offset.add(offs[0], offs[1]);
			minFps = config.minFps;
			maxFps = config.maxFps;
		}		

		if (animation.curAnim != null)
			animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
	}

	inline public static function getSplashSkinPostfix()
	{
		return ClientPrefs.data.splashSkin == ClientPrefs.defaultData.splashSkin ? "" : "-" + ClientPrefs.data.splashSkin.toLowerCase().replace(" ", "_");
	}

	function loadAnims(skin:String, ?animName:String):NoteSplashConfig
	{
		maxAnims = 0;
		frames = Paths.getSparrowAtlas(skin);
		if (frames == null)
		{
			trace('skin "$skin" failed to load!!');
			frames = Paths.getSparrowAtlas(skin = defaultNoteSplash + getSplashSkinPostfix());
			if (frames == null) // if you really need this, you really fucked something up
			{
				trace('skin "$skin" failed to load!! (AGAIN)');
				frames = Paths.getSparrowAtlas(skin = defaultNoteSplash);
			}
		}
		final config = precacheConfig(skin);
		_configLoaded = skin;

		if (animName == null)
			animName = config == null ? "note splash" : config.anim;

		while (true)
		{
			final animID = maxAnims + 1;
			for (i in 0...Note.colArray.length)
				if (!addAnimAndCheck('note$i-$animID', '$animName ' + Note.colArray[i] + ' $animID', 24, false))
					return config;

			maxAnims++;
		}
	}

	public static function precacheConfig(skin:String):NoteSplashConfig
	{
		if (configs.exists(skin))
			return configs.get(skin);

		final path = Paths.getPath('images/$skin.txt', TEXT, true);
		final configFile = CoolUtil.coolTextFile(path);
		if (configFile.length < 1)
			return null;
		
		final framerates = configFile[1].split(" ");
		final offs:Array<Array<Float>> = [];
		for (i in 2...configFile.length)
		{
			final animOffs = configFile[i].split(" ");
			offs.push([Std.parseFloat(animOffs[0]), Std.parseFloat(animOffs[1])]);
		}

		final config:NoteSplashConfig = {
			anim: configFile[0],
			minFps: Std.parseInt(framerates[0]),
			maxFps: Std.parseInt(framerates[1]),
			offsets: offs
		};
		configs.set(skin, config);
		return config;
	}

	function addAnimAndCheck(name:String, anim:String, ?framerate:Int = 24, ?loop:Bool = false)
	{
		if (!frames.framesHash.exists(anim + "0000"))
			return false;

		animation.addByPrefix(name, anim, framerate, loop);
		return true;
	}

	static var aliveTime:Float = 0;
	static final buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float)
	{
		if (alive && (aliveTime += elapsed) >= buggedKillTime)
			kill();

		super.update(elapsed);
	}
}
