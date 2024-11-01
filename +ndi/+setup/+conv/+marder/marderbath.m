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

for i=1:numel(et)
    eid = et(i).epoch_id;
    epochid.epochid = eid;
    for j=1:numel(stim)
        for k=1:size(bathTable,1)
            if (i>=bathTable{k,"firstFile"} && i<=bathTable{k,"lastFile"}) 
                % if we are in range, add it
                % step 1: loop over bathTargets
                bT = bathTable{k,"bathTargets"};
                for b=1:numel(bT)
                    locList = bathTargets.(bT{b});
                    for l=1:numel(locList)
                        bathLoc = ndi.database.fun.uberon_ontology_lookup("Identifier",locList(l).location);
                        mixTable = ndi.setup.conv.marder.mixtureStr2mixtureTable(bathTable{k,"mixtures"}{1},mixtureInfo)
                        mixTableStr = ndi.database.fun.writetablechar(mixTable);
                        stimulus_bath.location.ontologyNode = locList(l).location;
                        stimulus_bath.location.name = bathLoc.Name;
                        stimulus_bath.mixture_table = mixTableStr;
                        d{end+1}=ndi.document('stimulus_bath','stimulus_bath',stimulus_bath,'epochid',epochid)+...
                            S.newdocument();
                    end
                end
            end
        end
    end
end
