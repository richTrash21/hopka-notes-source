package shaders;

class RGBPalette
{
	public var shader(default, null):RGBPaletteShader;
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;

	public function new()
	{
		shader = new RGBPaletteShader();
		r = 0xFFFF0000;
		g = 0xFF00FF00;
		b = 0xFF0000FF;
		mult = 1.0;
	}

	@:noCompletion function set_r(color:FlxColor):FlxColor
	{
		shader.r.value[0] = color.redFloat;
		shader.r.value[1] = color.greenFloat;
		shader.r.value[2] = color.blueFloat;
		return r = color;
	}

	@:noCompletion function set_g(color:FlxColor):FlxColor
	{
		shader.g.value[0] = color.redFloat;
		shader.g.value[1] = color.greenFloat;
		shader.g.value[2] = color.blueFloat;
		return g = color;
	}

	@:noCompletion function set_b(color:FlxColor):FlxColor
	{
		shader.b.value[0] = color.redFloat;
		shader.b.value[1] = color.greenFloat;
		shader.b.value[2] = color.blueFloat;
		return b = color;
	}
	
	@:noCompletion function set_mult(value:Float):Float
	{
		return shader.mult.value[0] = (mult = FlxMath.bound(value, 0, 1));
	}
}

// automatic handler for easy usability
class RGBShaderReference
{
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;
	public var enabled(default, set):Bool = true;

	public var parent:RGBPalette;
	@:noCompletion var _owner:FlxSprite;
	@:noCompletion var _original:RGBPalette;

	public function new(owner:FlxSprite, ref:RGBPalette)
	{
		parent = ref;
		_owner = owner;
		_original = ref;
		owner.shader = ref.shader;

		@:bypassAccessor
		{
			r = parent.r;
			g = parent.g;
			b = parent.b;
			mult = parent.mult;
		}
	}
	
	@:noCompletion function set_r(value:FlxColor):FlxColor
	{
		if (allowNew && value != _original.r)
			cloneOriginal();
		return r = parent.r = value;
	}

	@:noCompletion function set_g(value:FlxColor):FlxColor
	{
		if (allowNew && value != _original.g)
			cloneOriginal();
		return g = parent.g = value;
	}

	@:noCompletion function set_b(value:FlxColor):FlxColor
	{
		if (allowNew && value != _original.b)
			cloneOriginal();
		return b = parent.b = value;
	}

	@:noCompletion function set_mult(value:Float):Float
	{
		if (allowNew && value != _original.mult)
			cloneOriginal();
		return mult = parent.mult = value;
	}

	@:noCompletion function set_enabled(value:Bool):Bool
	{
		_owner.shader = value ? parent.shader : null;
		return enabled = value;
	}

	public var allowNew = true;
	@:noCompletion function cloneOriginal()
	{
		if (allowNew)
		{
			allowNew = false;
			if (_original != parent)
				return;

			parent = new RGBPalette();
			parent.r = _original.r;
			parent.g = _original.g;
			parent.b = _original.b;
			parent.mult = _original.mult;
			_owner.shader = parent.shader;
			// trace('created new shader');
		}
	}
}

class RGBPaletteShader extends flixel.system.FlxAssets.FlxShader
{
	@:glFragmentHeader('
		#pragma header
		
		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord)
		{
			vec4 color = flixel_texture2D(bitmap, coord);
			if (!hasTransform)
				return color;

			if (color.a == 0.0 || mult == 0.0)
				return color * openfl_Alphav;

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;
			
			color = mix(color, newColor, mult);
			return color.a > 0.0 ? color : vec4(0.0);
		}')

	@:glFragmentSource('
		#pragma header

		void main()
		{
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')
	public function new()
	{
		super();
		r.value = [];
		g.value = [];
		b.value = [];
		mult.value = [];
	}
}
