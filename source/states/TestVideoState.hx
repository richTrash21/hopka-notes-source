package states;

import flixel.addons.transition.FlxTransitionableState;
import backend.VideoSprite;

class TestVideoState extends flixel.FlxState
{
	public static var videos(get, null):Array<String>;

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
			video.bitmap.onEndReached.add(() -> exit(), true);
			add(video);
			final status = video.load(FlxG.random.getObject(videos));
			trace('video loaded: $status');
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
		MusicBeatState.switchState(MainMenuState.new);
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
