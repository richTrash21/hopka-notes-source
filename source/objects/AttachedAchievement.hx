package objects;

#if ACHIEVEMENTS_ALLOWED

class AttachedAchievement extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var tag:String;
	public function new(x:Float = 0, y:Float = 0, name:String)
	{
		super(x, y);
		antialiasing = ClientPrefs.data.antialiasing;
		changeAchievement(name);
	}

	public function changeAchievement(tag:String)
	{
		this.tag = tag;
		reloadAchievementImage();
	}

	public function reloadAchievementImage()
	{
		loadGraphic(Paths.image('achievements/' + (backend.Achievements.isAchievementUnlocked(tag) ? tag : 'lockedachievement')));
		scale.set(0.7, 0.7);
		updateHitbox();
	}

	override function update(elapsed:Float)
	{
		if (sprTracker != null)
			setPosition(sprTracker.x - 130, sprTracker.y + 25);
		super.update(elapsed);
	}

	override function destroy()
	{
		sprTracker = null;
		super.destroy();
	}
}
#end