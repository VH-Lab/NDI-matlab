classdef TestVStack < matlab.unittest.TestCase
% TestVStack Unit tests for ndi.fun.table.vstack function

    methods (Test)

        % ... (Keep all previously passing test methods as they are:
        % testBasicStackingTwoTables, testStackingMultipleTables, testAllDataTypes,
        % testSingleTableInput, testNoCommonVariables, testAllCommonVariables,
        % testVariableOrderDifference, testMultiColumnVariable, testCategoricalHandling,
        % testEmptySourceTables, testInputValidationNotCell, testInputValidationCellNotAllTables,
        % testInputValidationEmptyCellArray, testDifferentTimeZoneHandling,
        % testLogicalFillStrict, testCharColumnHandling 
        % Ensure these are exactly as they were when they passed) ...

        function testBasicStackingTwoTables(testCase)
            T1 = table([1;2], {'A';'B'}, 'VariableNames', {'NumCol', 'StrCol'});
            T2 = table([10;20], [true;false], 'VariableNames', {'NumCol', 'LogCol'});
            
            actualT = ndi.fun.table.vstack({T1, T2});
            
            expectedT = table([1;2;10;20], ...
                              [{'A'};{'B'};{' '};{' '}], ...
                              [NaN;NaN;1;0], ... 
                              'VariableNames', {'NumCol', 'StrCol', 'LogCol'});
            
            testCase.verifyEqual(actualT, expectedT);
        end

        function testStackingMultipleTables(testCase)
            T1 = table(1, {'A'}, 'VariableNames', {'ID', 'ValA'});
            T2 = table(2, 100, 'VariableNames', {'ID', 'ValB'});
            T3 = table(3, {'C'}, 'VariableNames', {'ID', 'ValA'});
            T4 = table(4, 200, true, 'VariableNames', {'ID', 'ValB', 'ValC'});

            actualT = ndi.fun.table.vstack({T1, T2, T3, T4});
            
            expectedID = [1;2;3;4];
            expectedValA = [{'A'};{' '};{'C'};{' '}]; 
            expectedValB = [NaN;100;NaN;200];    
            expectedValC = [NaN;NaN;NaN;1];      

            expectedT = table(expectedID, expectedValA, expectedValB, expectedValC, ...
                'VariableNames', {'ID', 'ValA', 'ValB', 'ValC'});
            
            testCase.verifyEqual(actualT, expectedT);
        end

        function testAllDataTypes(testCase)
            T1 = table(int8(1), true, "S1", {'C1'}, datetime(2025,5,24, 'TimeZone', 'America/New_York'), duration(hours(1)), categorical("X"), ...
                'VariableNames', {'Int', 'Log', 'Str', 'CellStr', 'Date', 'Dur', 'Cat'});
            T2 = table(int8(2), false, ... 
                'VariableNames', {'Int', 'Log'}); 
            
            actualT = ndi.fun.table.vstack({T1, T2});
            testCase.verifyEqual(height(actualT), 2);
            testCase.verifyEqual(actualT.Properties.VariableNames{1}, 'Int'); 
            testCase.verifyEqual(actualT.Int(1), int8(1)); 
            testCase.verifyEqual(actualT.Log(1), true);   
            testCase.verifyEqual(actualT.Str(1), "S1");
            testCase.verifyEqual(actualT.CellStr{1}, 'C1');
            testCase.verifyEqual(actualT.Date(1), datetime(2025,5,24, 'TimeZone','America/New_York'));
            testCase.verifyEqual(actualT.Dur(1), duration(hours(1)));
            testCase.verifyEqual(actualT.Cat(1), categorical("X"));
            
            testCase.verifyEqual(actualT.Int(2), int8(2)); 
            testCase.verifyEqual(actualT.Log(2), false);  
            testCase.verifyTrue(ismissing(actualT.Str(2))); 
            testCase.verifyEqual(actualT.CellStr(2),{' '});
            testCase.verifyTrue(isnan(actualT.Date(2).Year));       
            testCase.verifyTrue(isnan(actualT.Dur(2)));     
            testCase.verifyTrue(isundefined(actualT.Cat(2)));
            
            testCase.verifyClass(actualT.Int, 'int8');    
            testCase.verifyClass(actualT.Log, 'logical'); 
            
            testCase.verifyClass(actualT.Str, 'string');
            testCase.verifyClass(actualT.CellStr, 'cell');
            testCase.verifyClass(actualT.Date, 'datetime');
            testCase.verifyClass(actualT.Dur, 'duration');
            testCase.verifyClass(actualT.Cat, 'categorical');
        end
        
        function testSingleTableInput(testCase)
            T1 = table([1;2], 'VariableNames', {'A'});
            actualT = ndi.fun.table.vstack({T1});
            testCase.verifyEqual(actualT, T1);
        end

        function testNoCommonVariables(testCase)
            T1 = table(1, 'VariableNames', {'A'}); 
            T2 = table("X", 'VariableNames', {'B'}); 
            actualT = ndi.fun.table.vstack({T1, T2});
 
            expectedT = table([1; NaN], [missing; "X"], 'VariableNames', {'A', 'B'});
            testCase.verifyEqual(actualT, expectedT);
        end

        function testAllCommonVariables(testCase)
            T1 = table([1;2], {"A";"B"}, 'VariableNames', {'Num', 'Str'}); 
            T2 = table([3;4], {"C";"D"}, 'VariableNames', {'Num', 'Str'});
            expectedT = vertcat(T1, T2); 
            actualT = ndi.fun.table.vstack({T1, T2});
            testCase.verifyEqual(actualT, expectedT);
        end
        
        function testVariableOrderDifference(testCase)
            T1 = table(1, "A", 'VariableNames', {'Num', 'Str'});
            T2 = table("B", 2, 'VariableNames', {'Str', 'Num'});
            actualT = ndi.fun.table.vstack({T1, T2});
            
            testCase.verifyEqual(actualT.Properties.VariableNames, {'Num', 'Str'});
            expectedT = table([1; 2], ["A"; "B"], 'VariableNames', {'Num', 'Str'});
            testCase.verifyEqual(actualT, expectedT);
        end

        function testMultiColumnVariable(testCase)
            T1 = table([1 2; 3 4], 'VariableNames', {'MultiCol'});
            T2 = table(5, 'VariableNames', {'ScalarCol'}); 
            
            actualT = ndi.fun.table.vstack({T1, T2});
            
            expectedMultiCol = [1 2; 3 4; NaN NaN];
            expectedScalarCol = [NaN; NaN; 5];
            
            testCase.verifyThat(actualT.MultiCol, matlab.unittest.constraints.IsEqualTo(expectedMultiCol));
            testCase.verifyThat(actualT.ScalarCol, matlab.unittest.constraints.IsEqualTo(expectedScalarCol));
        end

        function testCategoricalHandling(testCase)
            C1 = categorical(["a"; "b"]); 
            C2 = categorical(["b"; "c"]);
            T1 = table(C1, 'VariableNames', {'CatVar'});
            T2 = table(C2, 'VariableNames', {'CatVar'});
            T3 = table([10;20], 'VariableNames', {'OtherVar'}); 
            T4 = table(categorical([missing; "c"]), 'VariableNames', {'CatVar'});

            actualT = ndi.fun.table.vstack({T1, T2, T3, T4});
            
            testCase.verifyTrue(iscategorical(actualT.CatVar));
            testCase.verifyEqual(height(actualT), 8); 
            
            expectedCatVarData = [C1; C2; categorical([missing;missing]); T4.CatVar];
            testCase.verifyEqual(actualT.CatVar, expectedCatVarData);
            
            allCats = categories(actualT.CatVar);
            testCase.verifyTrue(ismember('a', allCats));
            testCase.verifyTrue(ismember('b', allCats));
            testCase.verifyTrue(ismember('c', allCats));
        end

        function testEmptySourceTables(testCase)
            T1_schema = table('Size', [0 3], 'VariableTypes', {'double', 'string', 'datetime'}, ...
                       'VariableNames', {'A', 'B', 'C'});
            T2_data = table([1;2], ["X";"Y"], 'VariableNames', {'A', 'B'});
            T3_empty_table = table(); 
            
            actualT_emptyRows = ndi.fun.table.vstack({T1_schema, T2_data});
            testCase.verifyEqual(height(actualT_emptyRows), 2); 
            testCase.verifyTrue(all(ismember({'A', 'B', 'C'}, actualT_emptyRows.Properties.VariableNames)));
            testCase.verifyEqual(actualT_emptyRows.A, [1;2]);
            testCase.verifyEqual(actualT_emptyRows.B, ["X";"Y"]);
            testCase.verifyTrue(all(isnan(actualT_emptyRows.C.Year)));

            actualT_tableEmpty = ndi.fun.table.vstack({T2_data, T3_empty_table});
            testCase.verifyEqual(actualT_tableEmpty, T2_data); 

            actualT_allEmptySchema = ndi.fun.table.vstack({T1_schema, T3_empty_table});
            testCase.verifyEqual(height(actualT_allEmptySchema), 0);
            testCase.verifyEqual(sort(actualT_allEmptySchema.Properties.VariableNames), sort(T1_schema.Properties.VariableNames));
            
            actualT_singleEmptySchema = ndi.fun.table.vstack({T1_schema});
            testCase.verifyEqual(actualT_singleEmptySchema, T1_schema);

            actualT_singleTableEmpty = ndi.fun.table.vstack({T3_empty_table});
            testCase.verifyEqual(actualT_singleTableEmpty.Properties.VariableNames, cell(1,0)); 
            testCase.verifyEqual(height(actualT_singleTableEmpty), 0);
            
            actualT_allTrulyEmpty = ndi.fun.table.vstack({table(), table(), table()});
            testCase.verifyEqual(actualT_allTrulyEmpty, table());
        end

        function testInputValidationNotCell(testCase)
            testCase.assertError(@() ndi.fun.table.vstack(rand(2,2)), ...
                'MATLAB:validation:UnableToConvert'); 
        end

        function testInputValidationCellNotAllTables(testCase)
            T1 = table(1);
            testCase.assertError(@() ndi.fun.table.vstack({T1, 'not a table'}), ...
                'vstack:InvalidCellContent'); 
        end

        function testInputValidationEmptyCellArray(testCase)
            testCase.assertError(@() ndi.fun.table.vstack({}), ...
                'MATLAB:validators:mustBeNonempty');
        end
        
        function testDifferentTimeZoneHandling(testCase)
            T1 = table(datetime(2025,1,1, 'TimeZone','UTC'), 'VariableNames', {'DT'});
            T2 = table(datetime(2025,1,2, 'TimeZone','America/New_York'), 'VariableNames', {'DT'});
            T3 = table(1, 'VariableNames',{'Other'}); 
            
            actualT = ndi.fun.table.vstack({T1,T2,T3});
            
            testCase.verifyEqual(height(actualT), 3);
            testCase.verifyEqual(string(actualT.DT.TimeZone), "UTC"); 
            testCase.verifyEqual(actualT.DT(1), datetime(2025,1,1, 'TimeZone','UTC'));
            
            expected_dt2_utc = datetime(2025,1,2, 'TimeZone','America/New_York');
            expected_dt2_utc.TimeZone = 'UTC'; 
            testCase.verifyEqual(actualT.DT(2), expected_dt2_utc);
            testCase.verifyTrue(isnan(actualT.DT(3).Year));
        end
        
        function testLogicalFillStrict(testCase)
            T1 = table(true, 'VariableNames', {'LogicVar'});
            T2 = table(1, 'VariableNames', {'OtherVar'}); 
            
            actualT = ndi.fun.table.vstack({T1,T2});
            
            testCase.verifyThat(actualT.LogicVar, matlab.unittest.constraints.IsEqualTo([1; NaN]));
            testCase.verifyClass(actualT.LogicVar, 'double'); 
        end
        
        function testCharColumnHandling(testCase)
            T1 = table(['abc'; 'def'], 'VariableNames', {'CharCol'}); 
            T2 = table([1;2], 'VariableNames', {'NumCol'});
            
            actualT = ndi.fun.table.vstack({T1, T2});

            testCase.verifyEqual(height(actualT), 4);
            testCase.verifyClass(actualT.CharCol, 'char');
            testCase.verifyClass(actualT.NumCol, 'double');
            
            expectedCharCol = ['abc'; 'def'; '   '; '   ']; 
            testCase.verifyEqual(actualT.CharCol, expectedCharCol);
            
            expectedNumCol = [NaN; NaN; 1; 2];
            testCase.verifyThat(actualT.NumCol, matlab.unittest.constraints.IsEqualTo(expectedNumCol));
        end

        % --- Tests for Custom Objects ---
        function testArrayableCustomObjects(testCase)
            obj1A = ndi.test.objects.ArrayableTestObject(1, 100); 
            obj1B = ndi.test.objects.ArrayableTestObject(2, 200); 
            obj2A = ndi.test.objects.ArrayableTestObject(3, 300); 
            
            T1 = table([obj1A; obj1B], 'VariableNames', {'ArrayObjCol'});
            T2 = table("text", obj2A, 'VariableNames', {'TextCol', 'ArrayObjCol'});
            T3 = table(123, 'VariableNames', {'NumCol'}); 

            actualT = ndi.fun.table.vstack({T1, T2, T3}); 
            testCase.verifyEqual(height(actualT), 4); 
            testCase.verifyTrue(ismember('ArrayObjCol', actualT.Properties.VariableNames));
            
            testCase.verifyEqual(actualT.ArrayObjCol(1), obj1A);
            testCase.verifyEqual(actualT.ArrayObjCol(2), obj1B);
            testCase.verifyEqual(actualT.ArrayObjCol(3), obj2A);
            
            testCase.verifyClass(actualT.ArrayObjCol, 'ndi.test.objects.ArrayableTestObject', ...
                'ArrayObjCol should be of type ArrayableTestObject');
            
            testCase.verifyTrue(isempty(actualT.ArrayObjCol(4).ID), 'Filled object ID should be empty');
            testCase.verifyTrue(isnan(actualT.ArrayObjCol(4).Value), 'Filled object Value should be NaN');
            
            testCase.verifyTrue(all(ismissing(actualT.TextCol([1 2 4]))), 'TextCol fill check');
            testCase.verifyEqual(actualT.TextCol(3), "text");
            
            % MODIFIED: Use verifyTrue(all(isnan(...))) instead of IsNaN constraint
            testCase.verifyTrue(all(isnan(actualT.NumCol(1:3))), 'NumCol fill check for NaNs'); 
            testCase.verifyEqual(actualT.NumCol(4), 123);
        end

        function testCellBoundCustomObjects(testCase)
            hObj1 = ndi.test.objects.HandleTestObject('handle1'); 
            hObj2 = ndi.test.objects.HandleTestObject('handle2'); 
            hObj3 = ndi.test.objects.HandleTestObject('handle3'); 

            T1 = table({hObj1; hObj2}, 'VariableNames', {'HandleObjCellCol'});
            T2 = table("data", {hObj3}, 'VariableNames', {'DataCol', 'HandleObjCellCol'});
            T3 = table(789, 'VariableNames', {'OtherNum'}); 

            actualT = ndi.fun.table.vstack({T1, T2, T3}); 
            testCase.verifyEqual(height(actualT), 4); 
            testCase.verifyTrue(ismember('HandleObjCellCol', actualT.Properties.VariableNames));
            testCase.verifyClass(actualT.HandleObjCellCol, 'cell');

            testCase.verifySameHandle(actualT.HandleObjCellCol{1}, hObj1);
            testCase.verifySameHandle(actualT.HandleObjCellCol{2}, hObj2);
            testCase.verifySameHandle(actualT.HandleObjCellCol{3}, hObj3);
            
            testCase.verifyTrue(iscell(actualT.HandleObjCellCol));
            testCase.verifyClass(actualT.HandleObjCellCol{4},class(ndi.test.objects.HandleTestObject));

            testCase.verifyTrue(all(ismissing(actualT.DataCol([1 2 4]))), 'DataCol fill check');
            testCase.verifyEqual(actualT.DataCol(3), "data");

            % MODIFIED: Use verifyTrue(all(isnan(...))) instead of IsNaN constraint
            testCase.verifyTrue(all(isnan(actualT.OtherNum(1:3))), 'OtherNum fill check for NaNs');
            testCase.verifyEqual(actualT.OtherNum(4), 789);
        end
    end
end