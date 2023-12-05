package objects;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;

enum Alignment
{
	LEFT;
	CENTERED;
	RIGHT;
}

class Alphabet extends FlxSpriteGroup
{
	public var text(default, set):String;

	public var bold:Bool;
	public var letters:Array<AlphaCharacter> = [];

	public var isMenuItem:Bool;
	public var targetY:Int = 0;
	public var changeX:Bool = true;
	public var changeY:Bool = true;

	public var alignment(default, set):Alignment = LEFT;
	public var scaleX(default, set):Float = 1.0;
	public var scaleY(default, set):Float = 1.0;
	public var rows:Int = 0;

	public var distancePerItem:FlxPoint = FlxPoint.get(20, 120);
	public var startPosition:FlxPoint = FlxPoint.get(); //for the calculations

	public function new(x:Float, y:Float, text:String = "", ?bold:Bool = true)
	{
		super(x, y);
		this.startPosition.set(x, y);
		this.bold = bold;
		this.text = text;
	}

	public function setAlignmentFromString(align:String)
	{
		alignment = switch(align.toLowerCase().trim())
			{
				case 'right':				RIGHT;
				case 'center' | 'centered':	CENTERED;
				default:					LEFT;
			}
	}

	private function set_alignment(align:Alignment)
	{
		alignment = align;
		updateAlignment();
		return align;
	}

	private function updateAlignment()
	{
		for (letter in letters)
		{
			final newOffset:Float = switch(alignment)
				{
					case CENTERED:	letter.rowWidth * 0.5;
					case RIGHT:		letter.rowWidth;
					default:		0;
				}
	
			letter.offset.x -= letter.alignOffset;
			letter.alignOffset = newOffset * scale.x;
			letter.offset.x += letter.alignOffset;
		}
	}

	private function set_text(newText:String)
	{
		newText = newText.replace('\\n', '\n');
		clearLetters();
		createLetters(newText);
		updateAlignment();
		return this.text = newText;
	}

	public function clearLetters()
	{
		var i:Int = letters.length;
		while (i > 0)
		{
			final letter:AlphaCharacter = letters[--i];
			if (letter != null)
			{
				letter.kill();
				letters.remove(cast remove(letter));
			}
		}
		letters = [];
		rows = 0;
	}

	public function setScale(newX:Float, ?newY:Float)
	{
		final lastX:Float = scale.x;
		final lastY:Float = scale.y;
		if (newY == null) newY = newX;
		@:bypassAccessor
		{
			scaleX = newX;
			scaleY = newY;
		}

		scale.set(newX, newY);
		softReloadLetters(newX / lastX, newY / lastY);
	}

	private function set_scaleX(value:Float)
	{
		if (value == scaleX) return value;

		final ratio:Float = value / scale.x;
		scale.x = scaleX = value;
		softReloadLetters(ratio, 1);
		return value;
	}

	private function set_scaleY(value:Float)
	{
		if (value == scaleY) return value;

		final ratio:Float = value / scale.y;
		scale.y = scaleY = value;
		softReloadLetters(1, ratio);
		return value;
	}

	public function softReloadLetters(ratioX:Float = 1, ?ratioY:Float)
	{
		if (ratioY == null) ratioY = ratioX;

		for (letter in letters)
		{
			if (letter != null)
			{
				letter.setupAlphaCharacter(
					(letter.x - x) * ratioX + x,
					(letter.y - y) * ratioY + y
				);
			}
		}
	}

	override function update(elapsed:Float)
	{
		if (isMenuItem)
		{
			final lerpVal:Float = FlxMath.bound(elapsed * 9.6, 0, 1);
			if (changeX) x = FlxMath.lerp(x, (targetY * distancePerItem.x) + startPosition.x, lerpVal);
			if (changeY) y = FlxMath.lerp(y, (targetY * 1.3 * distancePerItem.y) + startPosition.y, lerpVal);
		}
		super.update(elapsed);
	}

	override function destroy()
	{
		distancePerItem = FlxDestroyUtil.put(distancePerItem);
		startPosition = FlxDestroyUtil.put(startPosition);
		super.destroy();
	}

	public function snapToPosition()
	{
		if (isMenuItem)
		{
			if (changeX) x = (targetY * distancePerItem.x) + startPosition.x;
			if (changeY) y = (targetY * 1.3 * distancePerItem.y) + startPosition.y;
		}
	}

	private static final Y_PER_ROW:Float = 85;

	private function createLetters(newText:String)
	{
		var consecutiveSpaces:Int = 0;
		var xPos:Float = 0;
		final rowData:Array<Float> = [];
		rows = 0;
		for (character in newText.split(''))
		{
			if (character != '\n')
			{
				final spaceChar:Bool = (character == " " || (bold && character == "_"));
				if (spaceChar) consecutiveSpaces++;

				if (AlphaCharacter.allLetters.exists(character.toLowerCase()) && (!bold || !spaceChar))
				{
					if (consecutiveSpaces > 0)
					{
						if (!bold && xPos >= FlxG.width * 0.65)
						{
							xPos = 0;
							rows++;
						}
						else xPos += 28 * consecutiveSpaces * scaleX;
					}
					consecutiveSpaces = 0;

					final letter:AlphaCharacter = cast recycle(AlphaCharacter, true);
					letter.scale.set(scaleX, scaleY);

					letter.setupAlphaCharacter(xPos, rows * Y_PER_ROW * scale.y, character, bold);
					@:privateAccess letter.parent = this;

					letter.row = rows;
					xPos += letter.width + (letter.letterOffset.x + (!bold ? 2 : 0)) * scale.x;
					rowData[rows] = xPos;

					letters.push(cast add(letter));
				}
			}
			else
			{
				xPos = 0;
				rows++;
			}
		}

		for (letter in letters) letter.rowWidth = rowData[letter.row];
		if (letters.length > 0) rows++;
	}
}


///////////////////////////////////////////
// ALPHABET LETTERS, SYMBOLS AND NUMBERS //
///////////////////////////////////////////

typedef Letter = {?anim:String, ?offsets:Array<Float>, ?offsetsBold:Array<Float>}

class AlphaCharacter extends FlxSprite
{
	public var image(default, set):String;

	public static var allLetters:Map<String, Null<Letter>> = [
		//alphabet
		'a'  => null, 'b'  => null, 'c'  => null, 'd'  => null, 'e'  => null, 'f'  => null,
		'g'  => null, 'h'  => null, 'i'  => null, 'j'  => null, 'k'  => null, 'l'  => null,
		'm'  => null, 'n'  => null, 'o'  => null, 'p'  => null, 'q'  => null, 'r'  => null,
		's'  => null, 't'  => null, 'u'  => null, 'v'  => null, 'w'  => null, 'x'  => null,
		'y'  => null, 'z'  => null,

		//additional alphabet
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

		//symbols
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
		'?'  => {anim: 'question'}, //also used for "unknown"
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

		//additional symbols
		'¡'  => {anim: 'inverted exclamation', offsets: [0, -20], offsetsBold: [0, -20]},
		'¿'  => {anim: 'inverted question', offsets: [0, -20], offsetsBold: [0, -20]},
		'{'  => null,
		'}'  => null,
		'•'  => {anim: 'bullet', offsets: [0, 18], offsetsBold: [0, 20]}
	];

	var parent:Alphabet;
	public var alignOffset:Float = 0; //Don't change this
	public var letterOffset:FlxPoint = FlxPoint.get();

	public var row:Int = 0;
	public var rowWidth:Float = 0;
	public var character:String = '?';
	public function new()
	{
		super(x, y);
		image = 'alphabet';
		antialiasing = ClientPrefs.data.antialiasing;
	}
	
	public var curLetter:Letter = null;
	public function setupAlphaCharacter(x:Float, y:Float, ?character:String = null, ?bold:Null<Bool> = null)
	{
		this.x = x;
		this.y = y;

		if (parent != null)
		{
			if (bold == null) bold = parent.bold;
			this.scale.x = parent.scaleX;
			this.scale.y = parent.scaleY;
		}
		
		if (character != null)
		{
			this.character = character;
			final lowercase:String = this.character.toLowerCase();
			curLetter = (allLetters.exists(lowercase) ? allLetters.get(lowercase) : allLetters.get('?'));

			final suffix:String = (bold ? ' bold' : (isTypeAlphabet(lowercase) ? (lowercase != this.character ? ' uppercase' : ' lowercase') : ' normal'));
			final alphaAnim:String = (curLetter != null && curLetter.anim != null) ? curLetter.anim : lowercase;
			var anim:String = alphaAnim + suffix;
			animation.addByPrefix(anim, anim, 24);
			if (!animation.exists(anim))
			{
				anim = 'question' + (suffix == ' bold' ? suffix : ' normal');
				animation.addByPrefix(anim, anim, 24);
			}
			animation.play(anim, true);
		}
		updateHitbox();
	}

	public static function isTypeAlphabet(c:String) // thanks kade
	{
		final ascii = StringTools.fastCodeAt(c, 0);
		return (ascii >= 65 && ascii <= 90)
			|| (ascii >= 97 && ascii <= 122)
			|| (ascii >= 192 && ascii <= 214)
			|| (ascii >= 216 && ascii <= 246)
			|| (ascii >= 248 && ascii <= 255);
	}

	private function set_image(name:String)
	{
		if (frames == null) //first setup
		{
			image = name;
			frames = Paths.getSparrowAtlas(name);
			return name;
		}

		final lastAnim:String = animation != null ? animation.name : null;
		image = name;
		frames = Paths.getSparrowAtlas(name);
		this.scale.set(parent.scaleX,  parent.scaleY);
		alignOffset = 0;
		
		if (lastAnim != null)
		{
			animation.addByPrefix(lastAnim, lastAnim, 24);
			animation.play(lastAnim, true);
			
			updateHitbox();
		}
		return name;
	}

	public function updateLetterOffset()
	{
		if (animation.curAnim == null)
		{
			trace(character);
			return;
		}

		var add:Float = 110;
		if (animation.curAnim.name.endsWith('bold'))
		{
			if (curLetter != null && curLetter.offsetsBold != null)
			{
				letterOffset.set(curLetter.offsetsBold[0], curLetter.offsetsBold[1]);
			}
			add = 70;
		}
		else
		{
			if (curLetter != null && curLetter.offsets != null)
			{
				letterOffset.set(curLetter.offsets[0], curLetter.offsets[1]);
			}
		}
		add *= scale.y;
		offset.x += letterOffset.x * scale.x;
		offset.y += letterOffset.y * scale.y - (add - height);
	}

	override public function updateHitbox()
	{
		super.updateHitbox();
		updateLetterOffset();
	}

	override public function destroy()
	{
		letterOffset = FlxDestroyUtil.put(letterOffset);
		super.destroy();
	}
}
