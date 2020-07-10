package com.ndi;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;


public class TableFormat {
    List<Format> patterns = new ArrayList<>();

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
        HashSet<String> output = new HashSet<>(Arrays.asList(result));
        return output;
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