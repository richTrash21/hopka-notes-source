package states;

import backend.StateTransition;
import backend.VideoSprite;

class TestVideoState extends backend.BaseState
{
	public static var videos(get, null):Array<String>;

	var video:VideoSprite;

	override public function create()
	{
		FlxG.sound.music.volume = 0;
		StateTransition.skipNextTransOut = StateTransition.skipNextTransIn = true;

		final loading = new FlxText("LOADING...", 32);
		add(loading.screenCenter());

		sys.thread.Thread.create(() ->
		{
			final vid = FlxG.random.getObject(videos);
			trace('video loaded: $vid');

			add(video = new VideoSprite());
			video.bitmap.onEndReached.add(() -> exit(), true);
			video.load(vid);
			video.play();
			// loading.kill();
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
			exit();
		}
	}

	@:noCompletion extern inline function exit()
	{
		FlxG.switchState(MainMenuState.new);
	}

	// TODO: find where to upload all this shit cuz it's taking 60+ mb fucking hell
	@:noCompletion static function get_videos():Array<String>
	{
		if (videos == null)
			for (i => video in videos = sys.FileSystem.readDirectory("assets/videos"))
				videos[i] = 'assets/videos/$video';

		return videos;
	}
}
