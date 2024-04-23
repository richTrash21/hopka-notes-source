package states;

class AchievementsMenuState extends MusicBeatState
{
	public static final randomShit = ["childer", "him", "memes_overtaken_your_mind_evacuate_immediately", "wow_thats_awesome", "the_what", "invalid_field_moment", "ok_got_it_cool"];
	override public function create()
	{
		final bg = new FlxSprite(Paths.image(FlxG.random.getObject(randomShit)));
		bg.scaleBySize().updateHitbox();
		bg.alpha = 0.5;
		add(bg.screenCenter());
		add(new FlxText("NOT DONE YET!\nPRESS \"ESC\" TO EXIT!\n- rich").setFormat(32, CENTER).setBorderStyle(OUTLINE, FlxColor.BLACK, 4).screenCenter());
		super.create();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE)
			FlxG.switchState(MainMenuState.new);
	}
}