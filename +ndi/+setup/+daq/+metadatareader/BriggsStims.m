classdef BriggsStims < ndi.daq.metadatareader
    % NDI_DAQMETADATAREADER_BRIGGSSTIMS - a class for reading stims from Briggs lab 
    %
    %

    properties (GetAccess=public, SetAccess=protected)
    end;
    properties (Access=private)
    end;

    methods

        function obj = BriggsStims(varargin)
            % BRIGGSSTIMS - Create a new multifunction DAQ object
            %
            %  D = NDI.SETUP.DAQ.METADATAREADER.BRIGGSSTIMS()
            %  or
            %  D = NDI.SETUP.DAQ.METADATAREADER.BRIGGSSTIMS(STIMDATA_MAT_FILE)
            %
            %  Creates a new ndi.daq.metadatareader object. If TSVFILE_REGEXPRESSION
            %  is given, it indicates a regular expression to use to search EPOCHFILES
            %  for a tab-separated-value text file that describes stimulus parameters.
            %
            obj = obj@ndi.daq.metadatareader(varargin{:});
        end; % ndi.daq.metadatareader.BriggsStims

        function [parameters,stimorder,stimtimes] = readmetadatafromfile(ndi_daqmetadatareader_briggsStims_obj, file)
            % READMETADATAFROMFILE - read in metadata from the file that is identified
            %
            % PARAMETERS = READMETADATAFROMFILE(NDI_DAQMETADATAREADER_BRIGGS_STIMS_OBJ, FILE)
            %
            % Given a file that matches the metadata search criteria for an NDI_DAQMETADATAREADER_BRIGGS_STIMS
            % document, this function loads in the metadata.

            z = load(file,'-mat');

            base_parameters = z.stimData;
            base_parameters.stimParams = rmfield(base_parameters.stimParams,{'stimOrder','Value'});
            parameters = {};
            stimorder = z.stimData.stimParams.stimOrder(:);
            stimtimes = z.stimData.stimTimes(:);
            for i=1:numel(z.stimData.stimParams.Value) % if stimIDs change, this will use last value
                stimid = z.stimData.stimParams.stimOrder(i);
                params_here = base_parameters;
                params_here.Value = z.stimData.stimParams.Value(i);
                parameters{stimid} = params_here;
            end;
        end; % readmetadatafromfile()

    end; % methods

    methods (Static)
        function stimStructArray = briggsStruct2stimulusStruct(briggsStruct)
            % briggsStruct2stimulusStruct - create a standardized stimulus from a Briggs structure
            %
            % stimStructArray = ndi.daq.metadatareader.BriggsStims.briggsStruct2strimulusStruct(BRIGGSSTRUCT)
            %
            % Create a cell array of stimulus parameters from a Briggs stimulus parameters.
            %
                arguments
                   briggsStruct (1,1) struct
                end

                assert(iscell(briggsStruct.results1), "results1 must be a cell array");
                assert(iscell(briggsStruct.results2), "results2 must be a cell array");
                assert(isa(briggsStruct.units,'double'), "units must be a double array");

                p1 = cell2struct(briggsStruct.results1(:,2),matlab.lang.makeValidName(briggsStruct.results1(:,1)));           
                p2 = cell2struct(briggsStruct.results2(:,2),matlab.lang.makeValidName(briggsStruct.results2(:,1)));

                if numel(p2)>1
                    error(['Do not yet know how to process stimuli with multiple individual stimuli presented together. Tell us to add it!']);
                end

                fn1 = fieldnames(p1);
                fn2 = fieldnames(p2);

                stimStructArray = {};

                % validate
                reqFields1 = {'tuning','numSteps','numRepeats','gratDur','ITT','viewDist'};
                reqFieldsThere = ismember(reqFields1,fn1);
                if any(~reqFieldsThere)
                    index = find(~reqFieldsThere);
                    error(['Required field in data(X).results1 not found, for example: ' reqFields1{index(1)}]);
                end
                reqFields2 = {'x_coord','y_coord','size','contrast','SF','TF','Ori'};
                reqFieldsThere = ismember(reqFields2,fn2);
                if any(~reqFieldsThere)
                    index = find(~reqFieldsThere);
                    error(['Required field in data(X).results2 not found, for example: ' reqFields2{index(1)}]);
                end

                % make all values numbers instead of strings
                for i=1:numel(fn1) 
                    if ischar(getfield(p1,fn1{i})) | isstring(getfield(p1,fn1{i}))
                        p1 = setfield(p1,fn1{i},str2num(getfield(p1,fn1{i})));
                    end;
                end;
                for i=1:numel(fn2)
                    if ischar(getfield(p2,fn2{i})) | isstring(getfield(p2,fn2{i}))
                        p2 = setfield(p2,fn2{i},str2num(getfield(p2,fn2{i})));
                    end;
                end;

                % probably there are other stim type besides gratings
                % for right now assume gratings

                tuningTypeOrientation = 1;
                tuningTypeContrast = 2;
                tuningTypeSpatialFrequency = 3;
                tuningTypeTemporalFrequency = 4;
                tuningTypeSize = 5;

                p_base.imageType = 2; % assume sinewave
                p_base.animType = 4; % assume drifting grating
                p_base.flickerType = 0; % assume light->background->light                
                p_base.angle = vlt.data.conditional(p1.tuning==tuningTypeOrientation, briggsStruct.units, p2.Ori);
                p_base.distance = p1.viewDist;
                p_base.sFrequency = vlt.data.conditional(p1.tuning==tuningTypeSpatialFrequency, briggsStruct.units, p2.SF);
                p_base.tFrequency = vlt.data.conditional(p1.tuning==tuningTypeTemporalFrequency, briggsStruct.units, p2.TF);
                p_base.sPhaseShift = 0;
                p_base.rect = [p2.x_coord p2.y_coord p2.x_coord p2.y_coord] + (p2.size/2)*[-1 -1 1 1];
                p_base.contrast = vlt.data.conditional(p1.tuning==tuningTypeContrast, briggsStruct.units, p2.contrast) / 100;
                if p1.tuning==tuningTypeSize
                    p_base.rect = [p2.x_coord p2.y_coord p2.x_coord p2.y_coord] + vlt.data.colvec(briggsStruct.units)*[-1 -1 1 1];
                end
                p_base.background = 0.5;
                p_base.backdrop = 0.5;
                p_base.windowShape = 1;
                p_base.loops = 0;

                for i=1:numel(briggsStruct.units) % could also use p1.numSteps, these should be identical
                    p_here = p_base;
                    if p1.tuning==tuningTypeOrientation
                        p_here.angle = p_base.angle(i);
                    elseif p1.tuning==tuningTypeContrast
                        p_here.contrast = p_base.contrast(i);
                    elseif p1.tuning==tuningTypeSpatialFrequency
                        p_here.sFrequency = p_base.sFrequency(i);
                    elseif p1.tuning==tuningTypeTemporalFrequency
                        p_here.tFrequency = p_base.tFrequency(i);
                    elseif p1.tuning==tuningTypeSize
                        p_here.rect = p_base.rect(i,:);
                    end;
                    stimStructArray{i} = p_here;
                end;
        end % briggsStruct2stimulusStruct()

        function [stimOn,stimOff,stimGratCycle] = briggsStruct2stimulusTiming(briggsStruct)
            % briggsStruct2stimulusTiming - extract stimulus timing information from Briggs stimulus structure
            %
            % [stimOn,stimOff,stimGratCycle] = ndi.daq.metadatareader.BriggsStims.briggsStruct2strimulusTiming(BRIGGSSTRUCT)
            %
            % Returns the following:
            %  stimOn  : stim onset times for each stimulus
            %  stimOff : stim offset times for each stimulus
            %  stimGratCycle : a cell array of grating cycle times that
            %      belong to each stimulus
            %
                arguments
                   briggsStruct (1,1) struct
                end

                assert(iscell(briggsStruct.results1), "results1 must be a cell array");

                p1 = cell2struct(briggsStruct.results1(:,2),matlab.lang.makeValidName(briggsStruct.results1(:,1)));
                fn1 = fieldnames(p1);

                % validate
                reqFields1 = {'gratDur','ITT'};
                reqFieldsThere = ismember(reqFields1,fn1);
                if any(~reqFieldsThere)
                    index = find(~reqFieldsThere);
                    error(['Required field in data(X).results1 not found, for example: ' reqFields1{index(1)}]);
                end
                % make all values numbers instead of strings
                for i=1:numel(fn1) 
                    if ischar(getfield(p1,fn1{i})) | isstring(getfield(p1,fn1{i}))
                        p1 = setfield(p1,fn1{i},str2num(getfield(p1,fn1{i})));
                    end;
                end;

                interstimulusInterval = p1.ITT;
                stimulusDuration = p1.gratDur;
                entireStimulusDuration = interstimulusInterval + stimulusDuration;

                stimOn = NaN(numel(briggsStruct.trialstartts),1);
                stimOff = stimOn;
                stimGratCycle = {};

                for i=1:numel(briggsStruct.trialstartts)
                    stimGratCycle{i} = briggsStruct.gratcyclets(briggsStruct.gratcyclets>=briggsStruct.trialstartts(i)&briggsStruct.gratcyclets<=briggsStruct.trialendts(i));
                    stimOn(i) = stimGratCycle{i}(1);
                    stimOff(i) = stimOn(i) + stimulusDuration;
                end

        end % briggsStruct2stimulusTiming()
    end % static

end % classdef
