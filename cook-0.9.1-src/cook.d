/*
Copyright (c) 2011-2012 Timur Gafarov 

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

/*
 * Version history 
 * ('!' = breaking change)
 * --------------------------------------------------------------------------
 * 1.9.1:
 *     - Added "-dc" option to specify default config file
 *
 * 1.9:
 *     - Splitted the project to several modules instead of storing everything 
 *       in one large file
 *     - Added support for platform-specific configuration keys that override 
 *       default ones ("linux.compiler", "windows.lflags" etc)
 *     - Added full support for static libraries under Windows and Linux
 *     - Added a package system
 *
 * 1.8.5:
 *     - Cook now compiles with newest DMD version
 *
 * 1.8.4:
 *     - Added -run option to run the program after compilation
 *     - Added a configuration key to force modules (modules.forced)
 *       They will be compiled and linked even if no other module depend on them
 *     - Pattern formatting is now recursive
 *
 * 1.8.3:
 *     - Added support for default configuration file ("default.conf") 
 *       for all main modules in the project
 *
 * 1.8.2:
 *     - Fixed a minor bug with configuration overriding
 *
 * 1.8.1:
 *     - Fixed some bugs under Windows
 *
 * 1.8:
 *     - Added configuration file support
 *     - Rewrote configuration handling code
 *     - Added compile and link patterns (project.compile, project.link, project.linklib)
 *
 * 1.7.4:
 *     - Renamed project to "Cook"
 *
 * 1.7.3:
 *     - Module parser now recognizes import lists 
 *       (for example, "import std.stdio, std.string, std.conv;")
 *
 * 1.7.2:
 *     - Added -C, -L, -strip, -f, -s options
 *     - Fixed some bugs and name conflicts under Windows
 *
 * 1.7.1.1:
 *     - Rewrote backwards dependency tracer
 *     - Added reuse of object files between different dependency trees
 *     - Build now can build itself ($ ./build build -o build2)
 *     - Removed default entries in blackList
 *     - Renamed "t_module" to "Module", "appArgument" to "AppArgument",
 *       "collection" to "Collection".
 *     
 * 1.7.1:
 *   ! - Rewrote project scanner
 *   ! - Added support for multiple main modules/dependency trees in one project
 *   ! - Cache filename now depends on main module ("main.cache" by default), 
 *       so no need to explicitly define it
 *   ! - Renamed "-mcache" to "-cache" 
 *     - Added -emulate, -help options
 *     - Added help information
 *
 * 1.7.0:
 *   ! - Completely rewrote parameters handling code
 *   ! - Added -quiet, -rebuild, -nocache, -lib, -clean, -exclude, -release, 
 *       -mcache, -noconsole options
 *   ! - Renamed "build.cache" to "modules.cache"
 *   ! - Removed autodetection of *.rc file
 *     - Replaced tabs with spaces according to official D coding style
 *     - Added quit function
 */

module cook;

private
{
    import std.stdio;
    import std.file;
    import std.string;
    import std.array;
    import std.process;
    import std.c.process;
    import std.datetime;
    import std.path;

    import apparg;
    import collection;
    import conf;
    import lexer;
}

public:

/* 
 * Source code module, with all dependency information
 */
final class DModule
{
   public:
    SysTime lastModified;
    string[] imports;
    DModule[string] backdeps;
    string packageName;
    bool forceRebuild = false;
    bool rescan = true;

    string toString() 
    {
        string output = lastModified.toISOExtString() ~ " ";
        foreach(i,v; imports) 
            output ~= v ~ " ";
        return output;
    }
}

string[] getModuleDependencies(string filename, string ext)
{
    auto text = readText(filename);
    auto lex = new Lexer(text);
    lex.addDelimiters();
    string[] imports;
    bool nextIsModule = false;
    bool importList = false;

    string lexeme = "";
    do 
    {
        lexeme = lex.getLexeme();
        if (lexeme.length > 0)
        {
            if (nextIsModule)
            {
                imports ~= getModulePath(lexeme, ext);
                nextIsModule = false;
            }
            else if (lexeme == "import")
            {
                nextIsModule = true;
                importList = true;
            }
            else if ((lexeme == ",") && importList)
            {
                nextIsModule = true;
            }
            else if ((lexeme == ";") && importList)
            {
                importList = false;
            }
        }
    } 
    while (lexeme.length > 0);

    return imports;
}

// TODO: rename this to moduleToPath
string getModulePath(string modulename, string ext)
{
    string fname = modulename;
    fname = replace(fname, ".", "/");
    fname = fname ~ ext;
    return fname;	
}

string pathToModule(string path)
{
    string mdl = path;
    mdl = replace(mdl, "/", ".");
    return mdl;	
}

static string versionString = "1.9.1";

void printHelp(string programName, string programVersion)
{
    writeln
    (
        "cook ", programVersion, "\n",
        "A tool for building projects in D programming language\n",
        "\n"
        "Usage:\n",
        programName, " [MAINMODULE] [OPTIONS]\n",
        "\n"
        "OPTIONS:\n"
        "\n"
        "-help             Display this information\n"
        "-emulate          Don't write anything to disk\n"
        "-quiet            Don't print messages\n"
        "-rebuild          Force rebuilding all modules\n"
        "-nocache          Disable reading/writing module cache\n"
        "-lib              Build a static library instead of an executable\n"
        "-release          Compile modules in release mode\n"
        "-noconsole        Under Windows, hide application console window\n"
        "-strip            Remove debug symbols from resulting binary using \"strip\"\n"
        "                  (currently works only under Linux)\n"
        "-exclude FILE...  Don't compile specified module(s)\n"
        "-o FILE           Compile to specified filename\n"
        "-clean            Remove temporary data (object files, cache, etc.)\n"
        "-cache FILE       Use specified cache file\n"
        "-rc FILE          Under Windows, compile and link specified resource file\n"
      "-C\"...\"           Pass specified option(s) to compiler\n"
      "-L\"...\"           Pass specified option(s) to linker\n"
        "-run              Run program after compilation (does't work in emulation mode)\n"
        "-f [FILE]         Read MAINMODULE and OPTIONS from file (default \"params.cache\")\n"
        "-s [FILE]         Save MAINMODULE and OPTIONS to file (default \"params.cache\")\n"
        "-dc FILE          Specify default configuration file (default \"default.conf\")\n"
    );
}

int main(string[] args)
{
    // Arguments
    AppArgument[string] appArguments = readArguments(args);
    string buildProgramName = appArguments["_program_"].getName();
    string argumentsCacheFilename = "params.cache";
    if ("-f" in appArguments) 
    {
        if (appArguments["-f"].length > 1)
            argumentsCacheFilename = appArguments["-f"].getValueString(1);
        if (exists(argumentsCacheFilename))
        {
            string cache = readText(argumentsCacheFilename);
            appArguments = readArguments(buildProgramName ~ splitLines(cache));
            buildProgramName = appArguments["_program_"].getName();
        }
    }

    // Create a configuration manager
    Config config = new Config;
	
    // Quit at any time without throwing an exception
    void quit(int code, string message = "")
    {
        if (message.length > 0)
            writeln(message);

        if ("-debug" in appArguments)
        {
            writeln("Configuration:");
            string[] confContents;
            foreach(i, v; config.data) 
                confContents ~= std.string.format(" %s: %s", i, v);
            confContents.sort;
            foreach(i, v; confContents)
                writeln(v);
        }
	
        version(Windows) std.process.system("pause");
        std.c.process.exit(code);
    }

    // Set default configuration keys
    config.set("prephase", "", false);
    config.set("postphase", "", false);
    config.set("source.language", "d", false);
    config.set("source.ext", "d", false);
    config.set("compiler", "dmd", false);
    config.set("linker", "dmd", false);
    version(Windows) config.set("librarian", "lib", false);
    version(linux) config.set("librarian", "dmd", false);
    config.set("cflags", "", false); 
    config.set("lflags", "", false);
    //config.set("modules", ""); // TODO?
    config.set("obj.path", "", false);
    config.set("obj.path.use", "true", false);
    config.set("obj.ext", "", false);
    config.set("modules.main", "main", false);
    config.set("modules.forced", "", false);
    string tempTarget = "main";
    config.set("target", "", false);
    config.set("rc", "", false);
    config.set("modules.cache", "main.cache", false);
    config.set("project.compile", "%compiler% %cflags% -c %source% -of%object%", false);
    config.set("project.link", "%linker% %lflags% -of%target% %objects% %packages%", false);
    version(Windows) config.set("project.linklib", "%librarian% %lflags% -c -p32 -of%target% %objects%", false);
    version(linux) config.set("project.linklib", "%librarian% %lflags% -lib -of%target% %objects%", false);
    version(Windows) config.set("project.linkpkg", "%librarian% %lflags% -c -p32 -of%package% %objects%", false);
    version(linux) config.set("project.linkpkg", "%librarian% %lflags% -lib -of%package% %objects%", false);
    version(linux) config.set("project.run", "./%target%", false);
    version(Windows) config.set("project.run", "%target%", false);
    config.set("project.packages", "", false);

    string configFilename = "";

    bool emulate = false;
    bool quiet = false;
    bool forceRebuild = false;
    bool noCache = false;
    bool noBacktrace = false;
    bool library = false;
    bool noConsole = false;
    bool release = false;
    bool strip = false;

   /* 
    * TODO:
    * Since introducing multiple dependency trees per project 
    * in version 1.7.1, concept of a black list becomes obsolete
    */
    auto blackList = new Collection!string;

    DModule[string] projectModules;

    version(Windows)
    {
        config.set("obj.path", "o_windows/");
        config.set("obj.ext", ".obj");
    }
    version(linux)
    {
        config.set("obj.path", "o_linux/");
        config.set("obj.ext", ".o");
        config.append("lflags", "-L-rpath -L\".\" -L-ldl ");
    }

    if ("_main_" in appArguments)
    {
        if (appArguments["_main_"].length > 1)
        {
            config.set("modules.main", getModulePath(appArguments["_main_"].getValueString(1), ""));

            if (extension(config.get("modules.main")) == ".d") 
                config.set("modules.main", config.get("modules.main")[0..$-2]);
            tempTarget = config.get("modules.main");
            config.set("modules.cache", config.get("modules.main") ~ ".cache");
        }
    }
    if ("-emulate" in appArguments) emulate = true;
    if ("-quiet" in appArguments) quiet = true;
    if ("-rebuild" in appArguments) forceRebuild = true;
    if ("-nocache" in appArguments) noCache = true;
    if ("-nobacktrace" in appArguments) noBacktrace = true;
    if ("-lib" in appArguments) library = true;
    if ("-release" in appArguments) release = true;
    if ("-strip" in appArguments) strip = true;
    if ("-noconsole" in appArguments) noConsole = true;
    if ("-exclude" in appArguments) 
        blackList ~= appArguments["-exclude"].getValuesArray()[1..$];
    if ("-s" in appArguments)
    {
        if (appArguments["-s"].length > 1)
        {
            argumentsCacheFilename = appArguments["-s"].getValueString(1);
        }
        string argumentsCache = "";
        argumentsCache ~= config.get("modules.main");
        foreach(i, a; appArguments)
        {
            if (i != "_main_" && 
                i != "_program_" && 
                i != "-s") 
                argumentsCache ~= a.dump();
        }
        if (!emulate) std.file.write(argumentsCacheFilename, argumentsCache);
    }
    if ("-o" in appArguments)
    {
        if (appArguments["-o"].length > 1)
        {
            tempTarget = appArguments["-o"].getValueString(1);
        }
        else quit(1, "Please specify a valid filename for -o option");
    }
    if ("-clean" in appArguments)
    {
        if (exists(config.get("modules.cache"))) 
            std.file.remove(config.get("modules.cache"));
        if (exists("o_linux")) rmdirRecurse("o_linux");
        if (exists("o_windows")) rmdirRecurse("o_windows");
        return 0;
    }
    if ("-help" in appArguments)
    {
        printHelp(buildProgramName, versionString);
        return 0;
    }
    if ("-cache" in appArguments) 
    {
        if (appArguments["-cache"].length > 1) 
            config.set("modules.cache", appArguments["-cache"].getValueString(1));
        else quit(1, "Please specify a valid filename for -cache option");
    }
    if ("-rc" in appArguments) 
    {
        if (appArguments["-rc"].length > 1)
            config.set("rc", appArguments["-rc"].getValueString(1));
        else quit(1, "Please specify a valid filename for -rc option");
    }
    if ("-C" in appArguments) 
    {
        if (appArguments["-C"].length > 1) 
        {
            foreach(a; appArguments["-C"].getValuesArray()[1..$])
                config.append("cflags", a ~ " ");
        }
        else quit(1, "Please specify a string (\"...\") for -C option");
    }
    if ("-L" in appArguments) 
    {
        if (appArguments["-L"].length > 1) 
        {
            foreach(a; appArguments["-L"].getValuesArray()[1..$])
                config.append("lflags", a ~ " ");
        }
        else quit(1, "Please specify a string (\"...\") for -L option");
    }

    if ("./" ~ tempTarget != buildProgramName) config.set("target", tempTarget);
    else quit(1, "Illegal target name: \"" ~ tempTarget ~ "\" (conflicts with Cook executable)");

    version(Windows)
    {
        if (noConsole) 
            config.append("lflags", "-L/exet:nt/su:windows ");
    }

    // Read default configuration
    string defaultConfigFilename = "default.conf";
    if ("-dc" in appArguments) 
    {
        if (appArguments["-dc"].length > 1)
            defaultConfigFilename = appArguments["-dc"].getValueString(1);
            //config.set("conf", appArguments["-rc"].getValueString(1));
        else quit(1, "Please specify a valid filename for -dc option");
    }
    if (exists(defaultConfigFilename))
    {
        readConfiguration(config, defaultConfigFilename);
    }

    // Read project configuration
    configFilename = "./" ~ config.get("target") ~ ".conf";
    if (exists(configFilename))
    {
        readConfiguration(config, configFilename);
    }
	
    if (release) config.append("cflags", " -release -O ");
    //if (exists("derelict")) config.append("cflags", " -version=DerelictGL_ALL ");

    config.set("source.ext", ((config.get("source.ext")[0]=='.')?"":".") ~ config.get("source.ext"));

    // Read cache file
    if (exists(config.get("modules.cache")) && !noCache)
    {
        string cache = readText(config.get("modules.cache"));
        foreach (line; splitLines(cache))
        {
            auto tokens = split(line);
            auto m = new DModule;
            m.lastModified = SysTime.fromISOExtString(tokens[1]);
            auto deps = tokens[2..$];
            m.imports = deps;
            projectModules[tokens[0]] = m;			
        }
    }

    // Scan project
    void scanDependencies(string fileName)
    {
        DModule m;
        if (fileName in blackList) return;
        if (!(fileName in projectModules))
        {
            if (!quiet) writefln("Analyzing \"%s\"...", fileName);
            m = new DModule;
            m.lastModified = timeLastModified(fileName);
            auto deps = getModuleDependencies(fileName, config.get("source.ext"));
            m.imports = deps;
            m.packageName = pathToModule(dirName(fileName));
            projectModules[fileName] = m;

            foreach(importedModule; deps)
            {
                if (exists(importedModule))
                    scanDependencies(importedModule);
            }
        }
        else
        {
            m = projectModules[fileName];

            //TODO: cache this
            m.packageName = pathToModule(dirName(fileName));

            auto lm = timeLastModified(fileName);
            if (lm > m.lastModified)
            {
                if (!quiet) writefln("Analyzing \"%s\"...", fileName);
                m.lastModified = lm;
                auto deps = getModuleDependencies(fileName, config.get("source.ext"));
                m.imports = deps;
                m.forceRebuild = true;
                m.rescan = true;
            }

            if (m.rescan)
            {
                m.rescan = false;
                foreach(importedModule; m.imports)
                {
                    if (exists(importedModule))
                    scanDependencies(importedModule);
                }
            }		
        }
    }

    string mainModuleFilename = config.get("modules.main") ~ config.get("source.ext");
    if (exists(mainModuleFilename))
        scanDependencies(mainModuleFilename);
    else
        quit(1, "No main module found");

    if (projectModules.length == 0) 
        quit(1, "No source files found");

    // Trace backward dependencies.
    if (!noBacktrace)
    {
        foreach(modulei, modulev; projectModules)
        {
            foreach (mName; modulev.imports)
            {
                if (mName in projectModules)
                {
                    auto imModule = projectModules[mName];
                    imModule.backdeps[modulei] = modulev;
                }
            }
        }
        foreach(m; projectModules)
        {
            foreach(i, v; m.backdeps)
                v.forceRebuild = v.forceRebuild || m.forceRebuild;
        }
    }

    // Add forced modules
    foreach(fileName; split(config.get("modules.forced")))
    {
        if (exists(fileName))
        {
            DModule m = new DModule;
            m.lastModified = timeLastModified(fileName);
            auto deps = getModuleDependencies(fileName, config.get("source.ext"));
            m.imports = deps;
            projectModules[fileName] = m;

            foreach(importedModule; deps)
            {
                if (exists(importedModule))
                    scanDependencies(importedModule);
            }
        }
    }

    uint retcode;

    string projdir = std.path.getcwd();

    string linkList;
    string cache;

    // Prefase
    string prefase = formatPattern(config.get("prephase"), config, '%');
    if (prefase != "")
    {
        if (!quiet) writeln(prefase);
        if (!emulate)
        {
            retcode = std.process.system(prefase);
            if (retcode) quit(1, "Prefase error");
        }
    }

    string[] pkgList = split(config.get("project.packages"));

    // Compile modules
    if (config.get("obj.path") != "")
        if (!exists(config.get("obj.path"))) 
            mkdir(config.get("obj.path"));
    bool terminate = false;
    foreach (i, v; projectModules)
    {
        //TODO: cache module's package also
        cache ~= i ~ " " ~ v.toString() ~ "\n";

        if (!terminate && exists(i))
        {
            string targetObjectName = i;
            string tobjext = extension(targetObjectName);
            targetObjectName = targetObjectName[0..$-tobjext.length] ~ config.get("obj.ext");

            string targetObject = config.get("obj.path") ~ targetObjectName;

            if ((timeLastModified(i) > timeLastModified(targetObject, SysTime.min)) 
                || v.forceRebuild
                || forceRebuild)
            {
                if (config.get("obj.path.use") == "false")
                {
                    targetObject = targetObjectName;
                }

                config.set("source", i);
                config.set("object", targetObject);
                string command = formatPattern(config.get("project.compile"), config, '%');
                if (!quiet) writeln(command);
                if (!emulate)
                {
                    auto retcode = std.process.system(command);
                    if (retcode) terminate = true;
                }
            }

            if (config.get("obj.path.use") == "false")
            {
                targetObject = targetObjectName;
            }

            if (!matches(v.packageName, pkgList))
                linkList ~= targetObject ~ " ";
        }
    }

    if (terminate)
    {
        if (!emulate) 
            if (!noCache) std.file.write(config.get("modules.cache"), cache);
        quit(1);
    }

    // Compile resource file, if any
    version(Windows)
    {
        if (config.get("rc").length > 0)
        {
            string res = getName(config.get("rc")) ~ ".res ";
            string command = "windres -i " ~ config.get("rc") ~ " -o " ~ res ~ "-O res";
            if (!quiet) writeln(command);
            if (!emulate)
            {
                retcode = std.process.system(command);
                if (retcode) return 1;
            }
            config.append("lflags", res); 
        }
    }

    // Write cache file to disk
    if (!emulate) 
        if (!noCache) std.file.write(config.get("modules.cache"), cache);

    // Link packages, if any
    // WARNING: alpha stage, needs work!
    // TODO: do not relink a package, if it is unchanged
    // TODO: do not create a package, if it is empty
    string pkgLibList;
    foreach(pkg; pkgList)
    {
        string pkgLinkList;
        foreach(i, m; projectModules)
        {
            if (m.packageName == pkg)
            {
                string targetObjectName = i;
                string tobjext = extension(targetObjectName);
                targetObjectName = targetObjectName[0..$-tobjext.length] ~ config.get("obj.ext");

                string targetObject = config.get("obj.path") ~ targetObjectName;
                pkgLinkList ~= targetObject ~ " ";
            }
        }

        //TODO: pkgext should be a configuration key
        string pkgExt;
        version(Windows) pkgExt = ".lib";
        version(linux) pkgExt = ".a";

        config.set("objects", pkgLinkList);
        config.set("package", pkg ~ pkgExt);
        string command = formatPattern(config.get("project.linkpkg"), config, '%');
        if (!quiet) writeln(command);
        if (!emulate)
        {
            retcode = std.process.system(command);
            if (retcode) quit(1, "Package linking error");
        }

        pkgLibList ~= config.get("package") ~ " ";
    }

    // Link
    config.set("objects", linkList);           
    config.set("packages", pkgLibList);
    if (library)
    {
        version(Windows) config.append("target", ".lib");
        version(linux)   config.append("target", ".a");

        string command = formatPattern(config.get("project.linklib"), config, '%');
        if (!quiet) writeln(command);
        if (!emulate)
        {
            retcode = std.process.system(command);
            if (retcode) quit(1, "Linking error");
        }
    }
    else
    {
        version(Windows) config.append("target", ".exe");

        string command = formatPattern(config.get("project.link"), config, '%');
        if (!quiet) writeln(command);
        if (!emulate)
        {
            retcode = std.process.system(command);
            if (retcode) quit(1, "Linking error");
        }
    }

    // Strip
    if (strip)
    {
        version(linux)
        {
            string command = "strip " ~ config.get("target");
            if (!quiet) writeln(command);
            if (!emulate)
                std.process.system(command);
        }
    }

    // Run
    if ("-run" in appArguments && !library) 
    {
        if (!emulate)
        {
            string command = formatPattern(config.get("project.run"), config, '%');
            if (!quiet) writeln(command);
            if (!emulate)
                std.process.system(command);
        }
    }
	
    quit(0);

    return 0;
}

