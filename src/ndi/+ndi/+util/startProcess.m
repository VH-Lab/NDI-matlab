function p = startProcess(args, outFile, errFile)
% NDI.UTIL.STARTPROCESS - start a program in the background, without a shell
%
%   P = ndi.util.startProcess(ARGS, OUTFILE, ERRFILE)
%
%   Starts the program ARGS{1} with the arguments ARGS{2:end} and returns
%   at once with its java.lang.Process: P.isAlive(), P.exitValue(),
%   P.waitFor(SECONDS, java.util.concurrent.TimeUnit.SECONDS), P.destroy().
%   Its output goes to OUTFILE and its errors to ERRFILE (the same file is
%   fine). The program is found on the PATH, the same way on Linux, macOS
%   and Windows.
%
%   No shell is involved, so an argument with spaces, quotes or $ reaches
%   the program as it is: nothing needs quoting, and nothing in an
%   argument is ever run as a command.
%
%   On Linux and macOS the program gets the operating system's library
%   path, not MATLAB's (as ndi.common.systemCurlEnvPrefix arranges for
%   system()), so a system program loads the system's libraries.
%
%   See also: ndi.cloud.upload.CurlSender, ndi.util.KeepAwake

    arguments
        args cell
        outFile (1,:) char
        errFile (1,:) char
    end
    jargs = javaArray('java.lang.String', numel(args));
    for k = 1:numel(args)
        jargs(k) = java.lang.String(char(args{k}));
    end
    pb = java.lang.ProcessBuilder(jargs);
    if ~ispc
        env = pb.environment();
        orig = getenv('MW_ORIG_LD_LIBRARY_PATH');
        if isempty(orig)
            env.remove('LD_LIBRARY_PATH');
        else
            env.put('LD_LIBRARY_PATH', orig);
        end
    end
    if strcmp(outFile, errFile)
        pb.redirectErrorStream(true);
        pb.redirectOutput(java.io.File(outFile));
    else
        pb.redirectOutput(java.io.File(outFile));
        pb.redirectError(java.io.File(errFile));
    end
    p = pb.start();
end
