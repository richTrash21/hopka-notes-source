package objects;

import flixel.graphics.frames.FlxFrame;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var iconOffsets:Array<Float> = [0, 0];
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function new(char:String = 'bf', isPlayer:Bool = false, ?allowGPU:Bool = true) {
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		if (sprTracker != null) setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(this.char != char) {
			var name = Paths.fileExists('images/icons/' + char + '.png', IMAGE) ? 'icons/' + char : 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon

			var graphic = Paths.image(name, allowGPU);
			loadGraphic(graphic, true, Math.floor(graphic.width * 0.5), graphic.height);
			iconOffsets = [(width - 150) * 0.5, (height - 150) * 0.5];
			updateHitbox();

			animation.add(char, [0, 1], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			antialiasing = char.endsWith('-pixel') ? false : ClientPrefs.data.antialiasing;
		}
	}

	override function updateHitbox() {
		super.updateHitbox();
		offset.set(iconOffsets[0], iconOffsets[1]);
	}

	public function getCharacter():String
		return char;
}
