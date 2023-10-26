function subjectData = loadSubjects(S)
    % LOADSUBJECTS loads the probe data from ndi session
    %
    %  ndi.database.metadat_app.fun.loadSubjects(S)
    % Inputs:
    %  S - ndi.session.dir object
    % Output:
    %  PROBEDATA - a ndi.database.metadat_app.class.ProbeData object that contains all the probe data in session S
        
        if ~isa(S,'ndi.session.dir')
           error('METADATA_APP:loadSubjects:InvalidSession',...
              'Input must be an ndi.session object.'); 
        end
        subjects = S.database_search(ndi.query('','isa','subject'));
        subjectData = ndi.database.metadata_app.class.SubjectData();
       
        for i = 1:numel(subjects)
            subject_obj = subjectData.addItem();
            subject_obj.SubjectNameList{i} = subjects{i}.document_properties.subject.local_identifier;
        end
    end