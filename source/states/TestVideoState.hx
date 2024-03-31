package states;

import flixel.addons.transition.FlxTransitionableState;
import backend.VideoSprite;

class TestVideoState extends flixel.FlxState
{
	public static final videos = [
		Paths.video("flopa"),
		Paths.video("pep"),
		Paths.video("yap"),
		Paths.video("developing"),
		Paths.video("baraki"),
		Paths.video("Как налить чай в кружку"),
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224052634470842460/opening.mp4.mp4.mp4?ex=661c16d9&is=6609a1d9&hm=85aa92e8d05278d6c1ed83cea13122d5354b0a8029e61dcd59837dc16126a66a&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224030815630000138/win.mp4.mp4?ex=661c0287&is=66098d87&hm=6d543370811afa7dc964b42501e3c97659ec7681d16002436ef6ff907ea621c0&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224024590859112518/BALLS.mp4?ex=661bfcbb&is=660987bb&hm=cfccfa5be58850ec349b155f58fb91d0a3e74284b841fa3cd10a1258c49d57e3&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224026129531277412/opening.mp4_1.mp4?ex=661bfe2a&is=6609892a&hm=88c79fef4def8a9a80d19d5d1c9292b8adba5a22686eef2df49a6a79b2d90633&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224014826859270194/dubbing.mp4.mp4?ex=661bf3a3&is=66097ea3&hm=618de3917a7820cf19655a10fa35e1fa304e6675ff8f292cd124d1b863531ffa&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224057863501254837/This_is_probably_the_worst_dub_Ive_ever_made.mp4.mp4?ex=661c1bb8&is=6609a6b8&hm=c0155b4aa4ef6412212b4983ee3e3a87c84a49dac149806f08ec439b34c2cd77&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224066052564975766/HopKa_-_5rubles_choki_choki_animation_meme_in_fnf_bezdari_fridaynightfunkin_fnfmod_fnf_Mat.mp4?ex=661c2358&is=6609ae58&hm=268e6897d460640ca6e4e9cf7784337ba31a480ac00b0eb826f5426c9d9d4e4f&",
		"https://cdn.discordapp.com/attachments/791373867897192459/1214602136122429521/video0.mov?ex=661564e3&is=6602efe3&hm=d08c39cd1482d5ca6999b933e190ec9cc341925dbff8a42bdf30e217f4f0835e&"
	];
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
			video.bitmap.onEndReached.add(MusicBeatState.switchState.bind(DoiseRoomLMAO.new), true);
			add(video);
			final status = video.load(FlxG.random.getObject(videos));
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
			// FlxG.sound.music.volume = 1;
			MusicBeatState.switchState(DoiseRoomLMAO.new);
		}
	}
}