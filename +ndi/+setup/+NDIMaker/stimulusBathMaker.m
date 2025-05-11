classdef stimulusBathMaker < handle
    %UNTITLED4 Summary of this class goes here
    %   Detailed explanation goes here

    properties
        session
        mixtureFilename char
        bathtargetsFilename char
        mixtureStruct struct
        bathtargetsStruct struct
    end

    methods
        function obj = stimulusBathMaker(session,labName)
            %UNTITLED4 Construct an instance of this class
            %   Detailed explanation goes here
            
            % Input argument validation
            arguments
                session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
                labName (1,:) char
            end

            obj.session = session;

            labFolder = fullfile(ndi.common.PathConstants.RootFolder,...
                '+ndi','+setup','+conv',['+',labName]);

            % Get mixture structure
            obj.mixtureFilename = fullfile(labFolder,[labName,'_mixtures.json']);
            obj.mixtureStruct = jsondecode(fileread(obj.mixtureFilename));

            % Get bath targets structure
            obj.bathtargetsFilename = fullfile(labFolder,[labName,'_bathtargets.json']);
            obj.bathtargetsStruct = jsondecode(fileread(obj.bathtargetsFilename));
        end

        function docs = table2bathDocs(obj, variableTable, options)
            arguments
                obj
                variableTable
                options.BathVariable (1,:) char
                options.MixtureVariable (1,:) char
                options.MixtureDictionary struct = struct();
            end

            % Get stimulator id
            % stim = obj.session.getprobes('type','stimulator');
            % stimulatorid = stim{1}.id;
            
            % Get valid epochs
            epochInd = find(~isnan(variableTable.sessionInd));
            docs = cell(size(epochInd));

            for e = 1:numel(epochInd)

                % Get epoch id from data file name
                filename = variableTable.Properties.RowNames{epochInd(e)};
                epochid = ndi.fun.epoch.filename2epochid(obj.session,filename);

                % Get bath target string
                if any(strcmpi(fieldnames(variableTable),options.BathVariable))
                    bathtargetStrings = variableTable.(options.BathVariable){epochInd(e)};
                else
                    bathtargetStrings = options.BathVariable;
                end

                % Get mixture strings
                if any(strcmpi(fieldnames(variableTable),options.MixtureVariable))
                    mixtureStrings = variableTable.(options.MixtureVariable){epochInd(e)};
                else
                    mixtureStrings = options.MixtureVariable;
                end
                mixtureStrings = strsplit(mixtureStrings,' + ');
                mixtureStrings = replace(mixtureStrings,' ','_');
                for i = 1:numel(mixtureStrings)
                    if any(strcmpi(fieldnames(options.MixtureDictionary),mixtureStrings{i}))
                        mixtureStrings{i} = options.MixtureDictionary.(replace(mixtureStrings{i},' ','_'));
                    end
                    if ~any(strcmpi(fieldnames(obj.mixtureStruct),mixtureStrings{i}))
                        error('STIMULUSBATHMAKER:InvalidMixture',...
                            'Could not find the mixture named %s listed in the file %s.',...
                            mixtureStrings{i},obj.mixtureFilename)
                    end
                end

                docs{e} = createBathDoc(obj, stimulatorid, epochid, bathtargetStrings, mixutreStrings);
            end
        end

        function docs = createBathDoc(obj, stimulatorid, epochid, bathtargetStrings, mixtureStrings)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here

            % Get mixtureTable corresponding to mixtureString(s)
            mixtureNames = fieldnames(obj.mixtureStruct);
            if ischar(mixtureStrings)
                mixtureStrings = {mixtureStrings};
            end
            mixtureTable = table();
            for i = 1:numel(mixtureStrings)
                if ~any(contains(mixtureNames,mixtureStrings{i}))
                    error('STIMULUSBATHMAKER:InvalidMixtureString',...
                        '%s is not a valid mixture name in the mixtures file: %s.',...
                        mixtureStrings{i},obj.mixtureFilename)
                end
                mixtureTable = cat(1,mixtureTable,ndi.setup.conv.marder.mixtureStr2mixtureTable(...
                    mixtureStrings{i},obj.mixtureStruct));
            end

            % Get bath locations corresponding to bathtargetString(s)
            bathtargetNames = fieldnames(obj.bathtargetsStruct);
            if ischar(bathtargetStrings)
                bathtargetStrings = {bathtargetStrings};
            end
            locList = struct('location',{});
            for i = 1:numel(bathtargetStrings)
                if ~any(contains(bathtargetNames,bathtargetStrings{i}))
                    error('STIMULUSBATHMAKER:InvalidBathtargetString',...
                        '%s is not a valid bath target name in the bath targets file: %s.',...
                        bathtargetStrings{i},obj.bathtargetsFilename)
                end
                locList = cat(1,locList,obj.bathtargetsStruct.(bathtargetStrings{i}));
            end

            docs = {};
            for l = 1:numel(locList)

                % Define stimulus bath structure
                stimulus_bath.location.ontologyNode = locList(l).location;
                bathLoc = ndi.database.fun.uberon_ontology_lookup('Identifier',...
                    locList(l).location);
                stimulus_bath.location.name = bathLoc.Name;
                stimulus_bath.mixture_table = ndi.database.fun.writetablechar(mixtureTable);

                % Create stimulus bath document
                docs{end+1} = ndi.document('stimulus_bath',...
                    'stimulus_bath',stimulus_bath,...
                    'epochid',epochid) + ...
                    obj.session.newdocument();
                docs{end} = docs{end}.set_dependency_value(...
                    'stimulus_element_id',stimulatorid);
            end

            % Add stimulus_bath docs to database
        end
    end
end