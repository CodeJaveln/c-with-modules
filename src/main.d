import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.format;
import std.conv;
import std.uni;
import std.string;

enum MAX_NEST = 100;

static class CompilerException : Exception {
    import std.exception;

    mixin basicExceptionCtors;
}

struct CompilationContext {
    // If you are about to compile a file that is in this list, then rethink your life choices buddy
    string[] doNotRecompPaths;
    CMFile[] compiledFiles; 
    int currentNest;
}

struct CMFile {
    string path;
    string[] sourceLines;
    string[] headerLines;
}

CMFile compileFile(string path, ref CompilationContext ctx) {
    if (ctx.currentNest >= MAX_NEST) {
        throw new CompilerException("Hit recursive limit");
    }

    ctx.doNotRecompPaths ~= path;

    CMFile compiled;
    compiled.path = path;

    string headerGuard = path.stripExtension.replace(".", "_").replace("/", "_").replace("-", "_").toUpper ~ "_H";
    compiled.headerLines ~= format("#ifndef %s", headerGuard);
    compiled.headerLines ~= format("#define %s", headerGuard);

    string relativeHeaderPath = path.stripExtension.baseName ~ ".h";
    compiled.sourceLines ~= format("#include \"%s\"", relativeHeaderPath);

    bool pushSource = true;

    auto lines = File(path, "r").byLine;
    foreach (line; lines) {
        if (pushSource && line.stripRight == "#export open") {
            pushSource = false;
            continue;
        }
        else if (!pushSource && line.stripRight == "#export close") {
            pushSource = true;
            continue;
        }
        else if (pushSource && line.stripRight == "#export close") {
            throw new CompilerException("Can't close export when pushing source.");
        }
        else if (!pushSource && line.stripRight == "#export open") {
            throw new CompilerException("Can't open export when pushing header.");
        }

        string importString = "#import ";
        if (line.length >= importString.length && line[0 .. importString.length] == importString) {
            // TODO: more robust get the path way please
            string relativeDependencyPath = line.stripRight.to!string[importString.length + 1 .. $ - 1];
            string dependencyPath = compiled.path.dirName.buildPath(relativeDependencyPath).asNormalizedPath.array;

            writeln("relative dependency: ", relativeDependencyPath);
            writeln("dependency: ", dependencyPath);

            // Never previously compiled
            if (!ctx.doNotRecompPaths.any!(p => p == dependencyPath)) {
                ctx.currentNest++;
                auto compiledDependency = compileFile(dependencyPath, ctx);
                ctx.currentNest--;

                ctx.compiledFiles ~= compiledDependency;
            }

            if (pushSource) {
                compiled.sourceLines ~= format("#include \"%s.h\"", relativeDependencyPath.stripExtension);
            }
            else {
                compiled.headerLines ~= format("#include \"%s.h\"", relativeDependencyPath.stripExtension);
            }
            format("#include \"%s.h\"", relativeDependencyPath.stripExtension).writeln;
            continue;
        }

        if (pushSource) {
            compiled.sourceLines ~= line.to!string;
        }
        else {
            compiled.headerLines ~= line.to!string;
        }
    }

    compiled.headerLines ~= format("#endif /* %s */", headerGuard);

    return compiled;
}

void compileProject(string buildDir, string rootSrc) {
    CompilationContext ctx;

    auto rootFile = compileFile(rootSrc, ctx);
    ctx.compiledFiles ~= rootFile;

    buildDir.rmdirRecurse();
    buildDir.mkdir();

    foreach (cm; ctx.compiledFiles) {
        auto lePath = buildPath(buildDir, cm.path);
        mkdirRecurse(lePath.dirName);

        auto sourceFile = File(lePath.stripExtension ~ ".c", "w");
        foreach (sourceLine; cm.sourceLines) {
            sourceFile.writeln(sourceLine);
        }

        auto headerFile = File(lePath.stripExtension ~ ".h", "w");
        foreach (headerLine; cm.headerLines) {
            headerFile.writeln(headerLine);
        }
    }
}

void main(string[] args) {
    string buildDir = "build/";
    string rootSrc;

    auto helpInfo = getopt(
        args,
        "build-dir|b", "Build directory to put build stuff.", &buildDir,
        std.getopt.config.required,
        "root|r", "Required root of the project.", &rootSrc
    );

    buildDir.writeln;
    rootSrc.writeln;

    if (!buildDir.exists) {
        buildDir.mkdir();
    }
    assert(buildDir.isDir, "Build dir needs to be a directory.");

    compileProject(buildDir, rootSrc);
}
