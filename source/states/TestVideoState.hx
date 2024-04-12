package states;

import flixel.addons.transition.FlxTransitionableState;
import backend.VideoSprite;

class TestVideoState extends flixel.FlxState
{
	public static final videos = [
		"assets/videos/flopa.mp4",
		"assets/videos/pep.mp4",
		"assets/videos/yap.mp4",
		"assets/videos/developing.mp4",
		"assets/videos/baraki.mp4",
		"assets/videos/Как налить чай в кружку.mp4",
		"assets/videos/usa.mp4",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224052634470842460/opening.mp4.mp4.mp4?ex=661c16d9&is=6609a1d9&hm=85aa92e8d05278d6c1ed83cea13122d5354b0a8029e61dcd59837dc16126a66a&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224030815630000138/win.mp4.mp4?ex=661c0287&is=66098d87&hm=6d543370811afa7dc964b42501e3c97659ec7681d16002436ef6ff907ea621c0&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224024590859112518/BALLS.mp4?ex=661bfcbb&is=660987bb&hm=cfccfa5be58850ec349b155f58fb91d0a3e74284b841fa3cd10a1258c49d57e3&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224026129531277412/opening.mp4_1.mp4?ex=661bfe2a&is=6609892a&hm=88c79fef4def8a9a80d19d5d1c9292b8adba5a22686eef2df49a6a79b2d90633&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224014826859270194/dubbing.mp4.mp4?ex=661bf3a3&is=66097ea3&hm=618de3917a7820cf19655a10fa35e1fa304e6675ff8f292cd124d1b863531ffa&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224057863501254837/This_is_probably_the_worst_dub_Ive_ever_made.mp4.mp4?ex=661c1bb8&is=6609a6b8&hm=c0155b4aa4ef6412212b4983ee3e3a87c84a49dac149806f08ec439b34c2cd77&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224066052564975766/HopKa_-_5rubles_choki_choki_animation_meme_in_fnf_bezdari_fridaynightfunkin_fnfmod_fnf_Mat.mp4?ex=661c2358&is=6609ae58&hm=268e6897d460640ca6e4e9cf7784337ba31a480ac00b0eb826f5426c9d9d4e4f&",
		"https://cdn.discordapp.com/attachments/791373867897192459/1214602136122429521/video0.mov?ex=661564e3&is=6602efe3&hm=d08c39cd1482d5ca6999b933e190ec9cc341925dbff8a42bdf30e217f4f0835e&",
		"https://cdn.discordapp.com/attachments/791373867897192459/1225073961545498695/WAS_THAT_THE_BAIAIAIAISYUHAIAIAIIAHU.mp4?ex=661fce09&is=660d5909&hm=b01db1807981063c75cb60cd9753d25c26c777fe3435ff515f5e55c2904374b0&",
		"https://cdn.discordapp.com/attachments/791373867897192459/1225821395250843739/gummy_elephant.mp4?ex=66228623&is=66101123&hm=40ec5a0ec0d439cc5e6584f8376c1ed5dd92eee5aaa08c02806a43dab3bc5852&",
		"https://cdn.discordapp.com/attachments/1189283263869620286/1226587762355077262/Dude_16.mp4?ex=66254fdf&is=6612dadf&hm=9bb057ef7e7a905f87a70cee80cd768b44015809644d3dd8c1e9a2db0983f5aa&",
		"https://media.discordapp.net/attachments/1041755661630976052/1226757575421460482/videoplayback.mp4?ex=6625ee06&is=66137906&hm=1c362782f27bd4146891aeae057587acc4ff9eef014a890bf4cff017fa980219&",
		"https://media.discordapp.net/attachments/1041755661630976052/1226757576016920626/Hello_Everybody_My_Name_is_Welcome.mp4?ex=6625ee06&is=66137906&hm=96a8e15075c88201ed85d45fb7fd042aad6d34270c858b8c782a31618ac8aae9&",
		"https://cdn.discordapp.com/attachments/1041755661630976052/1226859208671232021/d0x02eahjV41c8-6.mp4?ex=66264cad&is=6613d7ad&hm=d0990e64e91c6c07cb6cf7d4398a6d7f3c05b9fdcf2acc69ac13e516828f4341&",
		"https://cdn.discordapp.com/attachments/1041755661630976052/1226861075568267274/M_V0Zt6YDONNCz3k.mp4?ex=66264e6a&is=6613d96a&hm=0bd29af185cc42d6bfa2fe6157f6c435259503bf08080fccea397fcd2567265a&",
		"https://cdn.discordapp.com/attachments/1189283263869620286/1226956115854753792/UQL4hFmdqq9CgRya.mp4?ex=6626a6ed&is=661431ed&hm=6e1b14f8bb3a612dc4619933569d4661d6565e36568028150e2a7db09f52ac27&",
		"https://cdn.discordapp.com/attachments/1041755661630976052/1227378521010343936/xgJ6GZoCLWb75JW8.mp4?ex=66283052&is=6615bb52&hm=fc4d833a79b89057ca29014fd3b7a54376eafd37672e62d25cfc0a3e4a748e31&",
		"https://cdn.discordapp.com/attachments/1041755661630976052/1227380655936114761/video_2024-04-10_02-12-22.mp4?ex=66283250&is=6615bd50&hm=fd657c8d6c21b9f6f21a769d82407d85cf7922c099ea530768a253d607098798&",
		"https://cdn.discordapp.com/attachments/1041755661630976052/1228303592302055474/y2mate.is_-__pick_up_that_can___no_f_ck_off_-DAv1SSX3xLg-144pp-1712918995.mp4?ex=662b8ddd&is=661918dd&hm=26e666ba22d631587fc0de5399e9911c7752c8eb51f6ce111c6bcb7b9ecc2dc9&",
		"https://cdn.discordapp.com/attachments/1219255780172107814/1228367472814456912/CctzRhXRaGog2swg.mp4?ex=662bc95b&is=6619545b&hm=c397e435b9dddcf8a4767780d03b0011d0ee9c4dd42c96693d15e74c72514556&"
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
			video.bitmap.onEndReached.add(() -> exit(), true);
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
			FlxG.sound.music.volume = 1;
			exit();
		}
	}

	@:noCompletion extern inline function exit()
	{
		MusicBeatState.switchState(MainMenuState.new);
	}
}
