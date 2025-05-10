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

        % function table2bathDocs(variableTable)
        % need to build mixture string
        % Post/Pre = aCSF
        % no post/pre w/o plus = manning_compound
        % + additional location
        % save json file table that maps info in variable table to mixture
        % names

        function docs = createBathDoc(obj, stimulatorid, epochid, bathtargetString, mixtureString)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here

           
            
            % Get mixtureTable corresponding to mixtureString
            mixtureNames = fieldnames(obj.mixtureStruct);
            if ~any(contains(mixtureNames,mixtureString))
                error('STIMULUSBATHMAKER:InvalidMixtureString',...
                    '%s is not a valid mixture name in the mixtures file: %s.',...
                    mixtureString,obj.mixtureFilename)
            end
            mixtureTable = ndi.setup.conv.marder.mixtureStr2mixtureTable(...
                    mixtureString,obj.mixtureStruct);

            % Get bath locations corresponding to bathtargetString
            bathtargetNames = fieldnames(obj.bathtargetsStruct);
            if ~any(contains(bathtargetNames,bathtargetString))
                error('STIMULUSBATHMAKER:InvalidBathtargetString',...
                    '%s is not a valid bath target name in the bath targets file: %s.',...
                    bathtargetString,obj.bathtargetsFilename)
            end
            locList = obj.bathtargetsStruct.(bathtargetString);

            % Get stimuli
            stim = obj.session.getprobes('type','stimulator');

            % Define epoch id for given epochNum
            et = stim{1}.epochtable();
            epochid.epochid = et(epochNum).epoch_id;

            docs = {};
            for s = 1:numel(stim)
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
                    docs{end} = docs{end}.set_dependency_value('stimulus_element_id',stim{s}.id);
                end
            end

            % Add stimulus_bath docs to database
        end
    end
end