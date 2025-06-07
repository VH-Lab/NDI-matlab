function docs = temptable2stimulusparameters(S)
    % TEMPTABLE2STIMULUSPARAMETERS - Create stimulusparameter documents for temperature for a Marder ndi session
    %
    % TEMPTABLE2STIMULUSPARAMETERS(S)
    %

    arguments
        S (1,1) ndi.session 
    end

    dirname = S.getpath();

    t = load([dirname filesep 'temptable.mat'],'-mat');

    temptable = t.temptable;

    stim = S.getprobes('type','stimulator');

    et = stim{1}.epochtable();

    item_const = ndi.database.fun.ndicloud_ontology_lookup('Name','Command temperature constant');
    item_start = ndi.database.fun.ndicloud_ontology_lookup('Name','Command temperature start');
    item_end = ndi.database.fun.ndicloud_ontology_lookup('Name','Command temperature end');

    const_o = ['NDIC:' int2str(item_const.Identifier)];
    temp_start = ['NDIC:' int2str(item_start.Identifier)];
    temp_end = ['NDIC:' int2str(item_end.Identifier)];

    last_match = [];

    docs = {};

    for i=1:numel(et)
        ind = find(strcmp(et(i).epoch_id,temptable.("epoch_id")));
        if ~isempty(ind)
            last_match = temptable(ind,:);
        end;
        if isempty(last_match), continue; end;

        for p=1:numel(stim)
            if strcmp(last_match.type,"constant")
                eid.epochid = et(i).epoch_id;
                d_struct.ontology_name = const_o;
                d_struct.name = 'Command temperature constant';
                d_struct.value = last_match.temp{1};
                d_here = ndi.document('stimulus_parameter','stimulus_parameter',d_struct,...
                    'epochid',eid) + S.newdocument();
                d_here = d_here.set_dependency_value('stimulus_element_id',stim{p}.id());
                docs{end+1} = d_here;
            end
            if strcmp(last_match.type,"change")
                eid.epochid = et(i).epoch_id;
                d_struct1.ontology_name = temp_start;
                d_struct1.name = 'starting temperature';
                d_struct1.value = last_match.temp{1}(1);
                d_here = ndi.document('stimulus_parameter','stimulus_parameter',d_struct1,...
                    'epochid',eid) + S.newdocument();
                d_here = d_here.set_dependency_value('stimulus_element_id',stim{p}.id());
                docs{end+1} = d_here;
                d_struct2.ontology_name = temp_end;
                d_struct2.name = 'ending temperature';
                d_struct2.value = last_match.temp{1}(2);
                d_here = ndi.document('stimulus_parameter','stimulus_parameter',d_struct2,...
                    'epochid',eid) + S.newdocument();
                d_here = d_here.set_dependency_value('stimulus_element_id',stim{p}.id());
                docs{end+1} = d_here;
            end
        end
    end
