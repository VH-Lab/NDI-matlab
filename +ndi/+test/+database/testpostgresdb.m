
disp('=========== TEST START =======');
%mypostgresdb = ndi.database.postgresdb( % insert your creator arguments here ); 
% here it connects to your postgres database
mypostgresdb = ndi.database.postgresdb("matthewgonzalgo","matthewgonzalgo","1Password!");
mypostgresdb.db.Message
disp('========== mypostgres made =============');
% json_info = '["one", "two", "three"]'
% matlab_struct = jsondecode(json_info)
%class(matlab_struct)
% Some issue with ndi.document handling non struct types?

s = struct('x',{'a','b'},'list','abc')
mydoc = ndi.document(s)

q = ndi.query('list','contains_string','abc','')
q.to_searchstructure

disp("=============== field =======================");
q.to_searchstructure.field
size(q.to_searchstructure)
isfield(q.to_searchstructure, 'operation')
%doc = mypostgresdb.search( ndi.query('list','exact_string','abc','') );
alldocids(mypostgresdb)
  % show that mydocs has the right value
sql1 = ndiquery_to_sql(mypostgresdb, q.to_searchstructure)
%do_search(mypostgresdb, sql1)
disp("================== 2 ========================");
q2 = ndi.query('id','exact_string','a7bb1907805e4b75af16fcb96c62ab14','');
ndiquery_to_sql(mypostgresdb, q2.to_searchstructure)

disp("================== 3 ========================");
q3 = ndi.query('id','exact_number','matlab','');
ndiquery_to_sql(mypostgresdb, q3.to_searchstructure)

close(mypostgresdb.db)
disp('DONE');
