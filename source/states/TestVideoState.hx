package states;

import flixel.addons.transition.FlxTransitionableState;
import backend.VideoSprite;

class TestVideoState extends flixel.FlxState
{
	static final videos = ["flopa", "pep"];
	var video:VideoSprite;

	override public function create()
	{
		FlxG.sound.music.volume = 0;
		FlxTransitionableState.skipNextTransOut = FlxTransitionableState.skipNextTransIn = true;
		video = new VideoSprite();
		final status = video.load(Paths.video(FlxG.random.getObject(videos)));
		video.bitmap.onEndReached.add(MusicBeatState.switchState.bind(MainMenuState.new), true);
		add(video);
		video.play();
		trace('video loaded: $status');
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.SPACE)
		{
			if (video.bitmap.isPlaying)
				video.pause();
			else
				video.resume();
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.music.volume = 1;
			MusicBeatState.switchState(MainMenuState.new);
		}
	}
}