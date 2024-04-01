package shaders;

typedef BlendModeShader =
{
	var uBlendColor:openfl.display.ShaderParameter<Float>;
}

class BlendModeEffect
{
	public var shader(default, null):BlendModeShader;

	public var color(default, set):FlxColor;

	public function new(shader:BlendModeShader, color:FlxColor):Void
	{
		shader.uBlendColor.value = [];
		this.shader = shader;
		this.color = color;
	}

	@:noCompletion inline function set_color(color:FlxColor):FlxColor
	{
		shader.uBlendColor.value[0] = color.redFloat;
		shader.uBlendColor.value[1] = color.greenFloat;
		shader.uBlendColor.value[2] = color.blueFloat;
		shader.uBlendColor.value[3] = color.alphaFloat;
		return color;
	}

	@:noCompletion inline function get_color():FlxColor
	{
		return FlxColor.fromRGBFloat(shader.uBlendColor.value[0], shader.uBlendColor.value[1], shader.uBlendColor.value[2], shader.uBlendColor.value[3]);
	}
}
