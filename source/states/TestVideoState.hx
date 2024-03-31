package states;

import flixel.addons.transition.FlxTransitionableState;
import backend.VideoSprite;

class TestVideoState extends flixel.FlxState
{
	static final videos = ["flopa", "pep", "yap", "developing", "baraki"];
	var video:VideoSprite;

	override public function create()
	{
		FlxG.sound.music.volume = 0;
		FlxTransitionableState.skipNextTransOut = FlxTransitionableState.skipNextTransIn = true;

		final loading = new FlxText("LOADING...", 32);
		add(loading.screenCenter());

		sys.thread.Thread.create(() ->
		{
			video = new VideoSprite();
			video.bitmap.onEndReached.add(MusicBeatState.switchState.bind(MainMenuState.new), true);
			add(video);
			final status = video.load(Paths.video(FlxG.random.getObject(videos)));
			trace('video loaded: $status');
			video.play();
			loading.kill();
		});
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.SPACE && video != null)
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