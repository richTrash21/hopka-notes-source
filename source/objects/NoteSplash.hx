package objects;

import shaders.RGBPalette;
import flixel.system.FlxAssets.FlxShader;

typedef NoteSplashConfig = {
	anim:String,
	minFps:Int,
	maxFps:Int,
	offsets:Array<Array<Float>>
}

class NoteSplash extends FlxSprite
{
	public var rgbShader:PixelSplashShaderRef;
	private var _textureLoaded:String = null;
	private var _configLoaded:String = null;

	inline public static final defaultNoteSplash:String = 'noteSplashes/noteSplashes';
	public static var configs:Map<String, NoteSplashConfig> = new Map<String, NoteSplashConfig>();

	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);

		var skin:String = (PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) ? PlayState.SONG.splashSkin : defaultNoteSplash + getSplashSkinPostfix();
		
		rgbShader = new PixelSplashShaderRef();
		shader = rgbShader.shader;
		precacheConfig(skin);
		_configLoaded = skin;
		//scrollFactor.set();
	}

	override function destroy()
	{
		configs.clear();
		super.destroy();
	}

	var maxAnims:Int = 2;
	public function setupNoteSplash(x:Float, y:Float, direction:Int = 0, ?note:Note = null) {
		setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
		aliveTime = 0;

		var texture:String = null;
		if(note != null && note.noteSplashData.texture != null) texture = note.noteSplashData.texture;
		else if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) texture = PlayState.SONG.splashSkin;
		else texture = defaultNoteSplash + getSplashSkinPostfix();
		
		var config:NoteSplashConfig = _textureLoaded != texture ? loadAnims(texture) : precacheConfig(_configLoaded);

		var tempShader:RGBPalette = null;
		if((note == null || note.noteSplashData.useRGBShader) && (PlayState.SONG == null || !PlayState.SONG.disableNoteRGB))
		{
			// If Note RGB is enabled:
			if(note != null && !note.noteSplashData.useGlobalShader)
			{
				
				if(note.noteSplashData.r != -1) note.rgbShader.r = note.noteSplashData.r;
				if(note.noteSplashData.g != -1) note.rgbShader.g = note.noteSplashData.g;
				if(note.noteSplashData.b != -1) note.rgbShader.b = note.noteSplashData.b;
				tempShader = note.rgbShader.parent;
			}
			else tempShader = Note.globalRgbShaders[direction];
		}

		alpha = note != null ? note.noteSplashData.a : ClientPrefs.data.splashAlpha;
		rgbShader.copyValues(tempShader);

		if(note != null) antialiasing = note.noteSplashData.antialiasing;
		if(PlayState.isPixelStage || !ClientPrefs.data.antialiasing) antialiasing = false;

		_textureLoaded = texture;
		offset.set(10, 10);

		var animNum:Int = FlxG.random.int(1, maxAnims);
		animation.play('note' + direction + '-' + animNum, true);
		animation.finishCallback = function(name:String) kill();
		
		var minFps:Int = 22;
		var maxFps:Int = 26;
		if(config != null)
		{
			var animID:Int = direction + ((animNum - 1) * Note.colArray.length);
			var offs:Array<Float> = config.offsets[FlxMath.wrap(animID, 0, config.offsets.length-1)];
			offset.x += offs[0];
			offset.y += offs[1];
			minFps = config.minFps;
			maxFps = config.maxFps;
		}
		else
		{
			offset.x += -58;
			offset.y += -55;
		}

		if(animation.curAnim != null) animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
	}

	public static function getSplashSkinPostfix()
		return (ClientPrefs.data.splashSkin != ClientPrefs.defaultData.splashSkin) ? '-' + ClientPrefs.data.splashSkin.trim().toLowerCase().replace(' ', '_') : '';

	function loadAnims(skin:String, ?animName:String = null):NoteSplashConfig {
		maxAnims = 0;
		frames = Paths.getSparrowAtlas(skin);
		var config:NoteSplashConfig = null;
		if(frames == null)
		{
			skin = defaultNoteSplash + getSplashSkinPostfix();
			frames = Paths.getSparrowAtlas(skin);
			if(frames == null) //if you really need this, you really fucked something up
			{
				skin = defaultNoteSplash;
				frames = Paths.getSparrowAtlas(skin);
			}
		}
		config = precacheConfig(skin);
		_configLoaded = skin;

		if(animName == null) animName = config != null ? config.anim : 'note splash';

		while(true) {
			var animID:Int = maxAnims + 1;
			for (i in 0...Note.colArray.length) {
				if (!addAnimAndCheck('note$i-$animID', '$animName ${Note.colArray[i]} $animID', 24, false))
					return config;
			}
			maxAnims++;
		}
	}

	public static function precacheConfig(skin:String)
	{
		if(configs.exists(skin)) return configs.get(skin);

		var path:String = Paths.getPath('images/$skin.txt', TEXT, true);
		var configFile:Array<String> = CoolUtil.coolTextFile(path);
		if(configFile.length < 1) return null;
		
		var framerates:Array<String> = configFile[1].split(' ');
		var offs:Array<Array<Float>> = [];
		for (i in 2...configFile.length)
		{
			var animOffs:Array<String> = configFile[i].split(' ');
			offs.push([Std.parseFloat(animOffs[0]), Std.parseFloat(animOffs[1])]);
		}

		var config:NoteSplashConfig = {
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
		if (!#if (flixel < "5.4.0") frames.framesHash.exists(anim + '0000') #else frames.exists(anim + '0000') #end) return false;
		animation.addByPrefix(name, anim, framerate, loop);
		return true;
	}

	static var aliveTime:Float = 0;
	inline static var buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float) {
		aliveTime += elapsed;
		if(alive && aliveTime >= buggedKillTime) kill();
		super.update(elapsed);
	}
}

class PixelSplashShaderRef {
	public var shader:PixelSplashShader = new PixelSplashShader();

	public function copyValues(tempShader:RGBPalette)
	{
		if(tempShader != null)
		{
			for (i in 0...3)
			{
				shader.r.value[i] = tempShader.shader.r.value[i];
				shader.g.value[i] = tempShader.shader.g.value[i];
				shader.b.value[i] = tempShader.shader.b.value[i];
			}
			shader.mult.value[0] = tempShader.shader.mult.value[0];
		}
		else shader.mult.value[0] = 0.0;
	}

	public function new()
	{
		shader.r.value = [0, 0, 0];
		shader.g.value = [0, 0, 0];
		shader.b.value = [0, 0, 0];
		shader.mult.value = [1];

		var pixel:Float = PlayState.isPixelStage ? PlayState.daPixelZoom : 1;
		shader.uBlocksize.value = [pixel, pixel];
	}
}

class PixelSplashShader extends FlxShader
{
	@:glFragmentHeader('
		#pragma header
		
		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;
		uniform vec2 uBlocksize;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec2 blocks = openfl_TextureSize / uBlocksize;
			vec4 color = flixel_texture2D(bitmap, floor(coord * blocks) / blocks);
			if (!hasTransform) {
				return color;
			}

			if(color.a == 0.0 || mult == 0.0) {
				return color * openfl_Alphav;
			}

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;
			
			color = mix(color, newColor, mult);
			
			if(color.a > 0.0) {
				return vec4(color.rgb, color.a);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	public function new() { super(); }
}