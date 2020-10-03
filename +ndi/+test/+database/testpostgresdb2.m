disp('=========== TEST2 START =======');
%mypostgresdb = ndi_postgresdb( % insert your creator arguments here ); 
% here it connects to your postgres database
mypostgresdb = ndi.database.postgresdb("matthewgonzalgo","matthewgonzalgo","");
mypostgresdb.db.Message

disp('=========== alldocids =======');
% ids = alldocids(mypostgresdb)
% ids{1}

disp('=========== add =======');
new_id = "matlabtest"
%a = containers.Map({'different'},["new data entry"])

add_data = table(new_id, 999, ...
    'VariableNames',{'id' 'data'});
%add(mypostgresdb, add_data, '');
% new_id2 = "diff"
% add_data2 = table(new_id2, {"different": "new data entry"}, ...
%     'VariableNames',{'id' 'data'});
sqlread(mypostgresdb.db, 'public.documents')

disp('=========== read =======');
read(mypostgresdb, new_id,3)
read(mypostgresdb, 'a7bb1907805e4b75af16fcb96c62ab14',3)


% disp('=========== remove =======');
% %remove(mypostgresdb, new_id, '')
% sqlread(mypostgresdb.db, 'public.documents')

close(mypostgresdb.db)
disp('=========== TEST2 DONE =======');
