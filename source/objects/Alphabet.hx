package objects;

import flixel.math.FlxPoint;
import openfl.text.TextFormatAlign;
import flixel.util.FlxDestroyUtil;

// rich: базированный алайн для алфавита ноу вей 🤯🤯
enum abstract Alignment(String) from String to Alignment to String
{
	var LEFT     = "left";
	var RIGHT    = "right";
	var CENTER   = "center";

	// alt for CENTER
	var CENTERED = "center";

	@:from inline public static function fromOpenFL(align:TextFormatAlign):Alignment
	{
		return switch (align)
		{
			case TextFormatAlign.CENTER:  CENTER;
			case TextFormatAlign.RIGHT:   RIGHT;
			default:                      LEFT;
		}
	}

	@:to inline public static function toOpenFL(align:Alignment):TextFormatAlign
	{
		return switch (align)
		{
			case CENTER:  TextFormatAlign.CENTER;
			case RIGHT:   TextFormatAlign.RIGHT;
			default:      TextFormatAlign.LEFT;
		}
	}
}

class Alphabet extends FlxTypedSpriteGroup<AlphaCharacter>
{
	inline static final Y_PER_ROW:Float = 85;
	inline static final SPACE_SIZE = 28;
	inline static final TAB_LEN = 4; // in spaces

	public var text(default, set):String;
	public var bold:Bool = false;

	public var isMenuItem:Bool = false;
	public var targetY:Int = 0;
	public var changeX:Bool = true;
	public var changeY:Bool = true;

	public var alignment(default, set):Alignment = LEFT;
	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;

	public var fieldWidth:Float = FlxG.width * .65;
	public var lettersLength(default, null):Int = 0;
	public var rows(default, null):Int = 0;

	public var distancePerItem:FlxPoint;
	public var startPosition:FlxPoint; // for the calculations

	public function new(?x:Float = 0, ?y:Float = 0, text:String = "", bold:Bool = true)
	{
		super(x, y);

		this.distancePerItem = FlxPoint.get(20, 120);
		this.startPosition = FlxPoint.get(x, y);
		this.bold = bold;
		this.text = text;
	}

	inline public function setAlignmentFromString(align:String)
	{
		alignment = align.toLowerCase().trim();
	}

	public function clearLetters()
	{
		forEachAlive((letter) ->
		{
			letter.ID = -(++letter.ID);
			letter.kill();
		});
		rows = 0;
	}

	public function setScale(newX:Float, ?newY:Float)
	{
		if (newY == null)
			newY = newX;

		final lastX = scale.x;
		final lastY = scale.y;
		scale.set(newX, newY);
		softReloadLetters(newX / lastX, newY / lastY);
	}

	public function softReloadLetters(ratioX:Float = 1, ?ratioY:Float)
	{
		if (ratioY == null)
			ratioY = ratioX;

		forEachAlive((letter) -> letter.setupAlphaCharacter((letter.x - x) * ratioX + x, (letter.y - y) * ratioY + y));
	}

	public function snapToPosition()
	{
		if (isMenuItem)
		{
			if (changeX)
				x = (targetY * distancePerItem.x) + startPosition.x;
			if (changeY)
				y = (targetY * 1.3 * distancePerItem.y) + startPosition.y;
		}
	}

	override public function update(elapsed:Float)
	{
		if (isMenuItem)
		{
			final lerpVal = FlxMath.bound(elapsed * 9.6, 0, 1);
			if (changeX)
				x = FlxMath.lerp(x, (targetY * distancePerItem.x) + startPosition.x, lerpVal);
			if (changeY)
				y = FlxMath.lerp(y, (targetY * 1.3 * distancePerItem.y) + startPosition.y, lerpVal);
		}
		super.update(elapsed);
	}

	override public function destroy()
	{
		distancePerItem = FlxDestroyUtil.put(distancePerItem);
		startPosition = FlxDestroyUtil.put(startPosition);
		super.destroy();
	}

	@:noCompletion function createLetters(newText:String)
	{
		rows = lettersLength = 0;

		var xPos = 0.;
		var consecutiveSpaces = 0;
		var rowData = new Array<Float>();

		var i = -1;
		var id = 0;
		var character:String;
		var letter:AlphaCharacter;
		while (++i < newText.length)
		{
			character = newText.charAt(i);
			if (character == "\n")
			{
				xPos = 0;
				rows++;
			}
			else
			{
				final spaceChar = (character == " " || (bold && character == "_"));
				if (spaceChar)
					consecutiveSpaces++;
				else if (character == "\t") // tabulation support yaay!!!
				{
					final TAB_SIZE = SPACE_SIZE * TAB_LEN * scale.x;
					xPos += TAB_SIZE - (xPos % TAB_SIZE);
				}

				if (AlphaCharacter.allLetters.exists(character.toLowerCase()) && !(bold && spaceChar))
				{
					if (consecutiveSpaces > 0)
					{
						xPos += SPACE_SIZE * consecutiveSpaces * scale.x;
						rowData[rows] = xPos;
						if (!bold && xPos >= fieldWidth)
						{
							xPos = 0;
							rows++;
						}
					}
					consecutiveSpaces = 0;

					letter = recycle(AlphaCharacter, true);
					letter.scale.copyFrom(scale);
					letter.rowWidth = 0;

					letter.setupAlphaCharacter(xPos, rows * Y_PER_ROW * scale.y, character, bold);
					letter.parent = this;

					letter.ID = id++;
					letter.row = rows;
					xPos += letter.width + (letter.letterOffset.x + (bold ? 0 : 2)) * scale.x;
					rowData[rows] = xPos;

					add(letter);
					lettersLength++;
				}
			}
		}
		forEachAlive((letter) -> letter.rowWidth = rowData[letter.row]);
		sort(CoolUtil.sortByID);

		if (lettersLength > 0)
			rows++;
	}

	@:noCompletion function updateAlignment(?align:Alignment)
	{
		if (align == null)
			align = alignment;

		forEachAlive((letter) ->
		{
			final newOffset = switch (align)
				{
					case CENTER:  letter.rowWidth * .5;
					case RIGHT:   letter.rowWidth;
					default:      0;
				}
	
			letter.offset.x -= letter.alignOffset;
			letter.alignOffset = newOffset * scale.x;
			letter.offset.x += letter.alignOffset;
		});
	}

	@:noCompletion inline function set_alignment(align:Alignment):Alignment
	{
		updateAlignment(align);
		return alignment = align;
	}

	@:noCompletion function set_text(newText:String):String
	{
		newText = newText.replace("\\n", "\n");
		clearLetters();
		createLetters(newText);
		updateAlignment(alignment);
		return this.text = newText;
	}

	@:noCompletion inline function set_scaleX(value:Float):Float
	{
		if (value == scale.x)
			return value;

		softReloadLetters(value / scale.x, 1);
		return scale.x = value;
	}

	@:noCompletion inline function set_scaleY(value:Float):Float
	{
		if (value == scale.y)
			return value;

		softReloadLetters(1, value / scale.y);
		return scale.y = value;
	}

	@:noCompletion inline function get_scaleX():Float return scale.x;
	@:noCompletion inline function get_scaleY():Float return scale.y;
}


///////////////////////////////////////////
// ALPHABET LETTERS, SYMBOLS AND NUMBERS //
///////////////////////////////////////////


typedef Letter = {
	?anim:Null<String>,
	?offsets:Array<Float>,
	?offsetsBold:Array<Float>
}

@:allow(objects.Alphabet)
class AlphaCharacter extends FlxSprite
{
	@:noCompletion inline static final fixAnimDebug = " instance 10";

	public static var allLetters:Map<String, Null<Letter>> = [
		// alphabet
		'a'  => null, 'b'  => null, 'c'  => null, 'd'  => null, 'e'  => null, 'f'  => null,
		'g'  => null, 'h'  => null, 'i'  => null, 'j'  => null, 'k'  => null, 'l'  => null,
		'm'  => null, 'n'  => null, 'o'  => null, 'p'  => null, 'q'  => null, 'r'  => null,
		's'  => null, 't'  => null, 'u'  => null, 'v'  => null, 'w'  => null, 'x'  => null,
		'y'  => null, 'z'  => null,

		// additional alphabet
		'á'  => null, 'é'  => null, 'í'  => null, 'ó'  => null, 'ú'  => null,
		'à'  => null, 'è'  => null, 'ì'  => null, 'ò'  => null, 'ù'  => null,
		'â'  => null, 'ê'  => null, 'î'  => null, 'ô'  => null, 'û'  => null,
		'ã'  => null, 'ë'  => null, 'ï'  => null, 'õ'  => null, 'ü'  => null,
		'ä'  => null, 'ö'  => null, 'å'  => null, 'ø'  => null, 'æ'  => null,
		'ñ'  => null, 'ç'  => {offsetsBold: [0, -11]}, 'š'  => null, 'ž'  => null, 'ý'  => null, 'ÿ'  => null,
		'ß'  => null,
		
		//numbers
		'0'  => null, '1'  => null, '2'  => null, '3'  => null, '4'  => null,
		'5'  => null, '6'  => null, '7'  => null, '8'  => null, '9'  => null,

		// symbols
		'&'  => {offsetsBold: [0, 2]},
		'('  => {offsetsBold: [0, 0]},
		')'  => {offsetsBold: [0, 0]},
		'['  => null,
		']'  => {offsets: [0, -1]},
		'*'  => {offsets: [0, 28], offsetsBold: [0, 40]},
		'+'  => {offsets: [0, 7], offsetsBold: [0, 12]},
		'-'  => {offsets: [0, 16], offsetsBold: [0, 16]},
		'<'  => {offsetsBold: [0, -2]},
		'>'  => {offsetsBold: [0, -2]},
		'\'' => {anim: 'apostrophe', offsets: [0, 32], offsetsBold: [0, 40]},
		'"'  => {anim: 'quote', offsets: [0, 32], offsetsBold: [0, 40]},
		'!'  => {anim: 'exclamation'},
		'?'  => {anim: 'question'}, // also used for "unknown"
		'.'  => {anim: 'period'},
		'❝'  => {anim: 'start quote', offsets: [0, 24], offsetsBold: [0, 40]},
		'❞'  => {anim: 'end quote', offsets: [0, 24], offsetsBold: [0, 40]},
		'_'  => null,
		'#'  => null,
		'$'  => null,
		'%'  => null,
		':'  => {offsets: [0, 2], offsetsBold: [0, 8]},
		';'  => {offsets: [0, -2], offsetsBold: [0, 4]},
		'@'  => null,
		'^'  => {offsets: [0, 28], offsetsBold: [0, 38]},
		','  => {anim: 'comma', offsets: [0, -6], offsetsBold: [0, -4]},
		'\\' => {anim: 'back slash', offsets: [0, 0]},
		'/'  => {anim: 'forward slash', offsets: [0, 0]},
		'|'  => null,
		'~'  => {offsets: [0, 16], offsetsBold: [0, 20]},

		// additional symbols
		'¡'  => {anim: 'inverted exclamation', offsets: [0, -20], offsetsBold: [0, -20]},
		'¿'  => {anim: 'inverted question', offsets: [0, -20], offsetsBold: [0, -20]},
		'{'  => null,
		'}'  => null,
		'•'  => {anim: 'bullet', offsets: [0, 18], offsetsBold: [0, 20]}
	];

	inline public static function isTypeAlphabet(c:String) // thanks kade
	{
		final ascii = c.fastCodeAt(0);
		return (ascii >= 65 && ascii <= 90)
			|| (ascii >= 97 && ascii <= 122)
			|| (ascii >= 192 && ascii <= 214)
			|| (ascii >= 216 && ascii <= 246)
			|| (ascii >= 248 && ascii <= 255);
	}

	public var image(default, set):String;

	public var alignOffset:Float = 0; // Don't change this
	public var letterOffset:FlxPoint = FlxPoint.get();

	public var row:Int = 0;
	public var rowWidth:Float = 0;
	public var character:String = "?";
	public var curLetter:Letter;

	@:noCompletion var parent:Alphabet;

	public function new()
	{
		super();
		image = "alphabet";
		antialiasing = ClientPrefs.data.antialiasing;
	}

	public function setupAlphaCharacter(x:Float, y:Float, ?character:String, ?bold:Bool)
	{
		setPosition(x, y);

		if (parent != null)
		{
			if(bold == null)
				bold = parent.bold;

			this.scale.copyFrom(parent.scale);
		}
		
		if (character != null)
		{
			final lowercase = (this.character = character).toLowerCase();
			curLetter = allLetters.exists(lowercase) ? allLetters.get(lowercase) : allLetters.get('?');

			final suffix = bold
				? " bold"
				: (isTypeAlphabet(lowercase)
					? (lowercase == this.character ? " lowercase" : " uppercase" )
					: " normal"
				);

			final alphaAnim = curLetter == null || curLetter.anim == null ? lowercase : curLetter.anim;

			var anim = alphaAnim + suffix;
			animation.addByPrefix(anim, anim + fixAnimDebug, 24);
			if (!animation.exists(anim))
			{
				anim = "question" + (suffix == " bold" ? suffix + fixAnimDebug : " normal");
				animation.addByPrefix(anim, anim, 24);
			}
			animation.play(anim, true);
		}
		updateHitbox();
	}

	public function updateLetterOffset()
	{
		if (animation.curAnim == null)
		{
			trace(character);
			return;
		}

		var add = 110.;
		letterOffset.set();
		if (animation.curAnim.name.endsWith("bold"))
		{
			if (curLetter != null && curLetter.offsetsBold != null)
				letterOffset.set(curLetter.offsetsBold[0], curLetter.offsetsBold[1]);

			add = 70;
		}
		else
		{
			if (curLetter != null && curLetter.offsets != null)
				letterOffset.set(curLetter.offsets[0], curLetter.offsets[1]);
		}
		offset += FlxPoint.weak(letterOffset.x * scale.x, letterOffset.y * scale.y - (add * scale.y - height));
	}

	override public function updateHitbox()
	{
		super.updateHitbox();
		updateLetterOffset();
	}

	override public function destroy()
	{
		letterOffset = FlxDestroyUtil.put(letterOffset);
		curLetter = null;
		parent = null;
		super.destroy();
	}

	@:noCompletion function set_image(name:String):String
	{
		if (frames == null) // first setup
		{
			frames = Paths.getSparrowAtlas(name);
			return image = name;
		}

		final lastAnim = animation?.name;
		frames = Paths.getSparrowAtlas(name);
		this.scale.copyFrom(parent.scale);
		alignOffset = 0;
		
		if (lastAnim != null)
		{
			animation.addByPrefix(lastAnim, lastAnim, 24);
			animation.play(lastAnim, true);
			updateHitbox();
		}
		return image = name;
	}
}
