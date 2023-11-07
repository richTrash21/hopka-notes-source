package objects;

class HealthIcon extends FlxSprite
{
	public var isPlayer(default, null):Bool = false;
	public var char(default, null):String = '';
	public var sprTracker:FlxSprite;

	public function new(char:String = 'bf', isPlayer:Bool = false, allowGPU:Bool = true) {
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		//scrollFactor.set();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		if(sprTracker != null) setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, allowGPU:Bool = true) {
		if(this.char != char) {
			var prevFrame:Int = 0;
			var flip:Bool = isPlayer;
			if(animation.curAnim != null) {
				prevFrame = animation.curAnim.curFrame;
				flip = animation.curAnim.flipX;
			}

			var name = Paths.fileExists('images/icons/' + char + '.png', IMAGE)
				? 'icons/' + char // Older versions of psych engine's support
				: 'icons/icon-' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; // Prevents crash from missing icon

			var graphic = Paths.image(name, allowGPU);
			loadGraphic(graphic, true, Math.floor(graphic.width * 0.5), graphic.height);
			iconOffsets = [(width - 150) * 0.5, (height - 150) * 0.5];
			updateHitbox();

			if(animation.getByName(char) == null)
				animation.add(char, [0, 1], 0, false, flip);
			animation.play(char, false, false, prevFrame);
			this.char = char;

			antialiasing = char.endsWith('-pixel') ? false : ClientPrefs.data.antialiasing;
		}
	}

	override function updateHitbox() {
		super.updateHitbox();
		offset.set(iconOffsets[0], iconOffsets[1]);
	}

	public function getCharacter():String return char;
}
