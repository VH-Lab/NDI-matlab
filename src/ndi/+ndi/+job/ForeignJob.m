classdef ForeignJob < ndi.job.Job
% NDI.JOB.FOREIGNJOB - a job this MATLAB can list but not run
%
%   ndi.job.Job.load returns one for a job.json whose kind no class here is
%   registered for (a job made by NDI-python, or by a package not on the
%   path), or whose formatVersion is newer than this code reads. Its state
%   and progress show in the Jobs pane like any job's; RUN, RESTART and
%   RESUME are refused, and REMOVE only deletes the record.
%
%   See also: ndi.job.Job, ndi.job.Job.register

    properties (Constant)
        Kind = ''
    end

    methods
        function run(obj)
            error('NDI:job:foreign', ['Job "%s" is of kind "%s" (last run by %s, ' ...
                'format %d), which this MATLAB cannot run.'], obj.title, obj.kind, ...
                obj.runtime, obj.formatVersion);
        end

        function restart(obj)
            obj.run();
        end

        function tf = canResume(~)
            tf = false;
        end
    end

    methods (Access = protected)
        function work(obj)
            obj.run();
        end
    end
end
