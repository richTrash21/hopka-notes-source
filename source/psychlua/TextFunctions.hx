package psychlua;

class TextFunctions
{
	public static function implement(funk:FunkinLua)
	{
		final game:PlayState = PlayState.instance;
		funk.set("makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float) {
			LuaUtils.resetTextTag(tag = tag.replace('.', ''));
			final leText:FlxText = new FlxText(x, y, width, text, 16);
			leText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			leText.cameras = [game.camHUD];
			leText.scrollFactor.set();
			leText.borderSize = 2;
			game.modchartTexts.set(tag, leText);
		});

		funk.set("setTextString", function(tag:String, text:String) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null)
			{
				obj.text = text;
				return true;
			}
			FunkinLua.luaTrace("setTextString: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		funk.set("setTextSize", function(tag:String, size:Int) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null)
			{
				obj.size = size;
				return true;
			}
			FunkinLua.luaTrace("setTextSize: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		funk.set("setTextWidth", function(tag:String, width:Float) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null)
			{
				obj.fieldWidth = width;
				return true;
			}
			FunkinLua.luaTrace("setTextWidth: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		funk.set("setTextBorder", function(tag:String, size:Int, color:String) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null)
			{
				if(size > 0)
				{
					obj.borderStyle = OUTLINE;
					obj.borderSize = size;
				}
				else
					obj.borderStyle = NONE;

				obj.borderColor = CoolUtil.colorFromString(color);
				return true;
			}
			FunkinLua.luaTrace("setTextBorder: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		funk.set("setTextColor", function(tag:String, color:String) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null)
			{
				obj.color = CoolUtil.colorFromString(color);
				return true;
			}
			FunkinLua.luaTrace("setTextColor: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		funk.set("setTextFont", function(tag:String, newFont:String) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null)
			{
				obj.font = Paths.font(newFont);
				return true;
			}
			FunkinLua.luaTrace("setTextFont: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		funk.set("setTextItalic", function(tag:String, italic:Bool) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null)
			{
				obj.italic = italic;
				return true;
			}
			FunkinLua.luaTrace("setTextItalic: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		funk.set("setTextAlignment", function(tag:String, alignment:String = 'left') {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null)
			{
				obj.alignment = switch(alignment.trim().toLowerCase())
					{
						case 'right':	RIGHT;
						case 'center':	CENTER;
						case 'justify':	JUSTIFY;
						default:		LEFT;
					}
				return true;
			}
			FunkinLua.luaTrace("setTextAlignment: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		funk.set("getTextString", function(tag:String) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null && obj.text != null) return obj.text;
			FunkinLua.luaTrace("getTextString: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});
		funk.set("getTextSize", function(tag:String) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null) return obj.size;
			FunkinLua.luaTrace("getTextSize: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return -1;
		});
		funk.set("getTextFont", function(tag:String) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null) return obj.font;
			FunkinLua.luaTrace("getTextFont: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});
		funk.set("getTextWidth", function(tag:String) {
			final obj:FlxText = LuaUtils.getTextObject(tag);
			if(obj != null) return obj.fieldWidth;
			FunkinLua.luaTrace("getTextWidth: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return 0;
		});

		funk.set("addLuaText", function(tag:String)
			if(game.modchartTexts.exists(tag))
				LuaUtils.getTargetInstance().add(game.modchartTexts.get(tag))
		);
		funk.set("removeLuaText", function(tag:String, destroy:Bool = true) {
			if(!game.modchartTexts.exists(tag)) return;

			final pee:FlxText = game.modchartTexts.get(tag);
			if(destroy) pee.kill();

			LuaUtils.getTargetInstance().remove(pee, true);
			if(destroy) {
				pee.destroy();
				game.modchartTexts.remove(tag);
			}
		});
	}
}