classdef AsynchProgressTracker < ndi.gui.component.internal.ProgressTracker

    methods
        function updateProgress(obj, currentStep)
            % updateProgress - Update progress by incrementing the current step

            % Todo: set.CurrentStep instead
            arguments
                obj (1,1) ndi.gui.component.internal.ProgressTracker
                currentStep (1,1) double = nan
            end

            if obj.IsFinished; return; end

            if obj.LastUpdate == 0
                obj.LastUpdate = tic();
            end

            % Update current step
            if isnan(currentStep)
                obj.CurrentStep = obj.CurrentStep + 1;
            else
                obj.CurrentStep = currentStep;
            end

            if obj.CurrentStep >= obj.TotalSteps
                obj.IsFinished = true;

                if ~ismissing(obj.DumpFilePath)
                    obj.dumpToFile()
                end
                return
            end

            if seconds(toc(obj.LastUpdate)) > obj.UpdateInterval
                obj.LastUpdate = tic();

                if ~ismissing(obj.DumpFilePath)
                    obj.dumpToFile()
                end
            end
        end
    end

    methods (Access = private)
        function dumpToFile(obj)
            propNames = ["CurrentStep", "TotalSteps", "TemplateMessage"];

            S = struct;
            for iPropName = propNames
                S.(iPropName) = obj.(iPropName);
            end

            fid = fopen(obj.DumpFilePath, "w");
            fwrite(fid, jsonencode(S));
            fclose(fid);
        end
    end
end
