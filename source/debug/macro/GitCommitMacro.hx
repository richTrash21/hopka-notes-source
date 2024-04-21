package debug.macro;

#if macro
import sys.io.Process;
#end

// from codename engine (https://github.com/FNF-CNE-Devs/CodenameEngine/blob/main/source/funkin/backend/system/macros/GitCommitMacro.hx)
class GitCommitMacro
{
	public static var number(get, null):Int;
	public static var hash(get, null):String;

	@:noCompletion static inline function get_number():Int
	{
		return __getCommitNumber();
	}
 
	@:noCompletion static inline function get_hash():String
	{
		return __getCommitHash();
	}
 
	// INTERNAL MACROS
	private static macro function __getCommitHash()
	{
		#if !display
		try
		{
			final proc = new Process("git", ["rev-parse", "--short", "HEAD"], false);
			proc.exitCode(true);
			return macro $v{proc.stdout.readLine()};
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
			return macro $v{Std.parseInt(proc.stdout.readLine())};
		}
		catch(e) {}
		#end
		return macro $v{0}
	}
}