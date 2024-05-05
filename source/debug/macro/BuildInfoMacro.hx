package debug.macro;

#if macro
import haxe.macro.Context;
import sys.io.Process;
#end

class BuildInfoMacro
{
	// from codename engine (https://github.com/FNF-CNE-Devs/CodenameEngine/blob/main/source/funkin/backend/system/macros/GitCommitMacro.hx)
	public static var commitNumber(get, never):String;
	public static var commitHash(get, never):String;
	public static var commit(get, never):String;

	// mine - rich
	public static var buildDate(get, never):String;
	public static var limeVersion(get, never):String;
	public static var openflVersion(get, never):String;

	@:noCompletion static inline function get_commitNumber():String
	{
		return __getCommitNumber();
	}

	@:noCompletion static inline function get_commitHash():String
	{
		return __getCommitHash();
	}

	@:noCompletion static inline function get_commit():String
	{
		return 'Commit $commitNumber ($commitHash)';
	}

	@:noCompletion static inline function get_buildDate():String
	{
		return __getBuildDate();
	}

	@:noCompletion static inline function get_limeVersion():String
	{
		return __getLimeVersion();
	}

	@:noCompletion static inline function get_openflVersion():String
	{
		return __getOpenflVersion();
	}

	// INTERNAL MACROS
	private static macro function __getCommitHash()
	{
		#if !display
		try
		{
			final proc = new Process("git", ["rev-parse", "--short", "HEAD"], false);
			proc.exitCode(true);
			return macro $v{"@" + proc.stdout.readLine()};
		}
		catch(e) {}
		#end
		return macro $v{"-"}
	}

	private static macro function __getCommitNumber()
	{
		#if !display
		try
		{
			final proc = new Process("git", ["rev-list", "HEAD", "--count"], false);
			proc.exitCode(true);
			return macro $v{proc.stdout.readLine()};
		}
		catch(e) {}
		#end
		return macro $v{"0"}
	}

	private static macro function __getBuildDate()
	{
		#if display
		return macro $v{"Build Date <unknown build date>"}
		#else
		return macro $v{"Build Date " + Date.now().toString()};
		#end
	}

	private static macro function __getLimeVersion()
	{
		#if display
		return macro $v{"Lime <unknown lime version>"}
		#else
		return macro $v{"Lime " + Context.definedValue("lime")};
		#end
	}

	private static macro function __getOpenflVersion()
	{
		#if display
		return macro $v{"OpenFL <unknown openfl version>"}
		#else
		return macro $v{"OpenFL " + Context.definedValue("openfl")};
		#end
	}
}