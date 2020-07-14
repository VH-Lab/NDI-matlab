package com.ndi;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class Rules {
    final List<String> correct = new ArrayList<>();
    final List<String> suggestions = new ArrayList<>();

    static Rules buildFromJSON(JSONObject input){
        Rules output = new Rules();
        JSONArray correctColumns = input.getJSONArray("correct");
        for (int i = 0; i < correctColumns.length(); i++){
            output = output.addExpectedColumn(correctColumns.getString(i));
        }
        if (input.has("suggestions")){
            JSONArray suggestedColumns = input.getJSONArray("suggestions");
            for (int i = 0; i < suggestedColumns.length(); i++){
                output = output.addSuggestedColumn(suggestedColumns.getString(i));
            }
        }
        return output;
    }

   /* public static Rules buildFromJSON(JSONObject input){
        Rules output = new Rules();
        if (!input.has("correct")){
            throw new IllegalArgumentException("Error building the Rule object: \nJSON files must contains the key \"correct\"");
        }
        JSONArray correctColumns;
        try{
            correctColumns = input.getJSONArray("correct");
        }
        catch(JSONException ex){
            throw new IllegalArgumentException("Error building the Rule object: \n the \"correct\" key must contain an array of string");
        }
        for (int i = 0; i < correctColumns.length(); i++){
            try{
                String column = correctColumns.getString(i);
                output.addExpectedColumn(column);
            }
            catch(JSONException ex){
                throw new IllegalArgumentException("Error building the Rule object:\n the 'correct' key must contain an array of string");
            }
        }
        if (input.has("suggestions")){
            JSONArray suggestedColumns;
            try{
                suggestedColumns = input.getJSONArray("suggestions");
            }
            catch(JSONException ex){
                throw new IllegalArgumentException("\"Error building the Rule object:\n the 'suggestions' key must contain an array of string\"");
            }
            for (int i = 0; i < suggestedColumns.length(); i++){
                try{
                    String colName = suggestedColumns.getString(i);
                    output.addSuggestedColumn(colName);
                }
                catch(JSONException ex){
                    throw new IllegalArgumentException("Error building the Rule object:\n the suggestions key must contain an array of string");
                }
            }
        }
        return output;
    }*/

    public Rules addExpectedColumn(String colName){
        correct.add(colName);
        return this;
    }

    public Rules addExpectedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addExpectedColumn(eachColName);
        }
        return this;
    }

    public Rules addSuggestedColumn(String colName){
        suggestions.add(colName);
        return this;
    }

    public Rules addSuggestedColumn(List<String> colName){
        for (String eachColName : colName){
            this.addSuggestedColumn(eachColName);
        }
        return this;
    }
}
