package com.ndi;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;


public class TableFormat {
    List<Format> patterns = new ArrayList<>();

    static TableFormat buildFromJSON(JSONObject input){
        TableFormat output = new TableFormat();
        JSONArray arr = input.getJSONArray("format");
        if (arr.length () == 0){
            throw new IllegalArgumentException("Error building the TableFormat object, the format value must be a list with length greater than 0");
        }
        String[] format = new String[arr.length()];
        for (int i = 0; i < arr.length(); i++){
            format[i] = arr.getString(i);
        }
        output = output.addFormat(format);
        if(input.has("entryFormat")){
            arr = input.getJSONArray("entryFormat");
            for (int i = 0; i < arr.length(); i++){
                if (!arr.isNull(i)){
                    output = output.addEntryPattern(i, arr.getString(i));
                }
            }
        }
        return output;
    }

    public TableFormat addFormat(String[] format){
        this.patterns = new ArrayList<>();
        for (String each : format){
            this.patterns.add(new Format(each, null));
        }
        this.patterns.add(new Format("", null));
        return this;
    }

    public TableFormat addEntryPattern(int index, String entryPattern){
        this.patterns.get(index).entryPattern = entryPattern;
        return this;
    }

    public static class Format{
        String pattern;
        String entryPattern;

        public Format(String pattern, String entryPattern){
            this.pattern = pattern;
            this.entryPattern = entryPattern;
        }
    }

    HashSet<String> parseEntry(String input, int index){
        if (this.patterns.get(index).entryPattern == null){
            return null;
        }
        String[] result = input.split(this.patterns.get(index).entryPattern);
        return new HashSet<>(Arrays.asList(result));
    }

    /**
     * Split the line of text into an ArrayList of string, using the specified format
     * specified by the user
     *
     * @param input the line of string we want to split
     * @return      an ArrayList of string being split using the given format
     */
    ArrayList<String> parseLine(String input){
        ArrayList<String> output = new ArrayList<>();
        String res = input;
        int index = 0;
        for (TableFormat.Format eachPattern : this.patterns){
            if (index == this.patterns.size()-1){
                break;
            }
            int location = res.indexOf(eachPattern.pattern);
            if (location == -1){
                throw new IllegalArgumentException("Pattern cannot be found");
            }
            String tobeAdded = res.substring(0, location);
            if (tobeAdded.equals("")){
                output.add(null);
            }
            else{
                output.add(res.substring(0, location));
            }
            if (location + eachPattern.pattern.length() <= input.length())
                res = res.substring(location + eachPattern.pattern.length());
            index += 1;
        }
        if (res.equals("")){
            output.add(null);
        }
        else{
            output.add(res);
        }
        return output;
    }

    Map<String, Integer> parseColumns(String input){
        List<String> columns;
        columns = this.parseLine(input);
        Map<String, Integer> col2index = new HashMap<>();
        int index = 0;
        for (String column : columns) {
            col2index.put(column, index++);
        }
        return col2index;
    }
}