function d = marderbath(S)
% MARDERBATH - add bath information to a Marder session
%
% D = MARDERBATH(S)
%
% Create NDI documents of type 'stimulus_bath' based on the mixture table
% at location [S.path filesep 'bath_table.csv']
%

arguments 
	S (1,1) ndi.session 
end

d = {};

stim = S.getprobes('type','stimulator');

et = stim{1}.epochtable();

marderFolder = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+setup','+conv','+marder');

mixtureInfo = jsondecode(fileread(fullfile(marderFolder,"marder_mixtures.json")));

bathTargets = jsondecode(fileread(fullfile(marderFolder,"marder_bathtargets.json")));

bathTable = readtable(fullfile(S.getpath(),"bath_table.csv"),"Delimiter",',');

locTable = vlt.data.emptystruct('Identifier','bathLoc');


for i=1:numel(et)
    eid = et(i).epoch_id;
    epochid.epochid = eid;
    for j=1:numel(stim)
        stimid = stim{j}.id();
        disp(['Working on stimulator ' int2str(j) ' of ' int2str(numel(stim)) ', epoch ' int2str(i) ' of ' int2str(numel(et)) '.']);
        for k=1:size(bathTable,1)
            tokensFirst = regexp(bathTable{k,"firstFile"}, '_(\d+)\.', 'tokens');
            tokensLast = regexp(bathTable{k,"lastFile"}, '_(\d+)\.', 'tokens');
            firstFile = str2double(tokensFirst{1}{1});
            lastFile = str2double(tokensLast{1}{1});
            if (i>=firstFile && i<=lastFile) 
                % if we are in range, add it
                % step 1: loop over bathTargets
                bT = bathTable{k,"bathTargets"};
                for b=1:numel(bT)
                    locList = bathTargets.(bT{b});
                    for l=1:numel(locList)
                        index = find(strcmp(locList(l).location,{locTable.Identifier}));
                        if isempty(index)
                            bathLoc = ndi.database.fun.uberon_ontology_lookup("Identifier",locList(l).location);
                            locTable(end+1) = struct('Identifier',locList(l).location,'bathLoc',bathLoc);
                        else
                            bathLoc = locTable(index).bathLoc;
                        end
                        mixTable = ndi.setup.conv.marder.mixtureStr2mixtureTable(bathTable{k,"mixtures"}{1},mixtureInfo);
                        mixTableStr = ndi.database.fun.writetablechar(mixTable);
                        stimulus_bath.location.ontologyNode = locList(l).location;
                        stimulus_bath.location.name = bathLoc.Name;
                        stimulus_bath.mixture_table = mixTableStr;
                        d{end+1}=ndi.document('stimulus_bath','stimulus_bath',stimulus_bath,'epochid',epochid)+...
                            S.newdocument();
                        d{end} = d{end}.set_dependency_value('stimulus_element_id',stimid);
                    end
                end
            end
        end
    end
end
