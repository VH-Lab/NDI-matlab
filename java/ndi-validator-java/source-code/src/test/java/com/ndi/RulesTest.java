package com.ndi;

import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.Collections;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.fail;

class RulesTest {

    @Test
    void addColumns(){
        Rules test = new Rules()
                .addExpectedColumn("expColumn1")
                .addExpectedColumn("expColumn2")
                .addSuggestedColumn("corrColumn1")
                .addExpectedColumn("expColumn3")
                .addSuggestedColumn("corrColumn2");
        assertEquals(test.getCorrectColumns(), Arrays.asList("expColumn1", "expColumn2", "expColumn3"));
        assertEquals(test.getSuggestedColumns(), Arrays.asList("corrColumn1", "corrColumn2"));
    }

    @Test
    void addListOfColumns(){
        Rules test = new Rules()
                    .addExpectedColumn(Collections.emptyList())
                    .addSuggestedColumn("suggestColumn1")
                    .addSuggestedColumn("suggestColumn2")
                    .addExpectedColumn(Arrays.asList("correctColumn2", "correctColumn3", "correctColumn4"))
                    .addExpectedColumn("correctColumn1")
                    .addSuggestedColumn(Arrays.asList("suggestColumn3", "suggestColumn4", "suggestColumn5"));
        assertEquals(test.getCorrectColumns(), Arrays.asList("correctColumn2", "correctColumn3", "correctColumn4", "correctColumn1"));
        assertEquals(test.getSuggestedColumns(), Arrays.asList("suggestColumn1", "suggestColumn2", "suggestColumn3", "suggestColumn4", "suggestColumn5"));
    }

    @Test
    void duplicateAdd(){
        try{
            Rules test = new Rules().addSuggestedColumn("col1")
                                    .addExpectedColumn("col1");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Rules Initialization Error: cannot have duplicate correct columns or overlapping suggestions columns and correct columns", ex.getMessage());
        }
        try{
            Rules test = new Rules().addExpectedColumn("col1")
                                    .addSuggestedColumn("col1");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Rules Initialization Error: cannot have duplicate suggested columns or overlapping suggestions columns and correct columns", ex.getMessage());
        }
        try{
            Rules test = new Rules().addExpectedColumn("col1")
                    .addExpectedColumn("col1");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Rules Initialization Error: cannot have duplicate correct columns or overlapping suggestions columns and correct columns", ex.getMessage());
        }
        try{
            Rules test = new Rules().addSuggestedColumn("col1")
                    .addSuggestedColumn("col1");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Rules Initialization Error: cannot have duplicate suggested columns or overlapping suggestions columns and correct columns", ex.getMessage());
        }
    }

    @Test
    void testJSON(){
        JSONObject sample1 = new JSONObject("{\n" +
                "   correct : ['col1','col2','col3']," +
                "   suggestions : ['sug1']" +
                "}  ");
        Rules test = Rules.buildFromJSON(sample1);
        assertEquals(Arrays.asList("col1", "col2", "col3"), test.getCorrectColumns());
        assertEquals(Collections.singletonList("sug1"), test.getSuggestedColumns());

        try{
            JSONObject sample2 = new JSONObject("{\n" +
                    "   correct : [col1,col2,col3]," +
                    "   suggestions : [col1]" +
                    "}  ");
            Rules test2 = Rules.buildFromJSON(sample2);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("Rules Initialization Error: cannot have duplicate suggested columns or overlapping suggestions columns and correct columns", ex.getMessage());
        }
    }

}