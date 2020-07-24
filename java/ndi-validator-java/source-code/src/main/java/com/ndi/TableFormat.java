package com.ndi;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * This class is used to store the format of the text file that the tabular data
 * was stored in such that the Validator can interpret the text file correctly.
 */
public class TableFormat {
    List<Format> patterns = new ArrayList<>();

    /**
     * Build a text file from JSON document. This method does not perform
     * JSON document input validation check. It is assumed that the validation
     * is performed when EnumFormatValidator was constructed
     *
     * @param input an instance of JSONObject representing the fields of the
     *              Table Format class
     * @return      an instance of TableFormat
     * @throws IllegalArgumentException when list of string representing how columns should be split is empty
     * or when the size of the entryFormat list does not match with the number of column (1 more than the number of
     * formatColumn)
     */
    static TableFormat buildFromJSON(JSONObject input){
        if (input == null){
            throw new IllegalArgumentException("TableFormat Initialization Error: input cannot be null");
        }
        TableFormat output = new TableFormat();
        JSONArray arr = input.getJSONArray("format");
        if (arr.length () == 0){
            throw new IllegalArgumentException("TableFormat Initialization Error: the format value must be a list with length greater than 0");
        }
        String[] format = new String[arr.length()];
        for (int i = 0; i < arr.length(); i++){
            format[i] = arr.getString(i);
        }
        output = output.addFormat(format);
        if(input.has("entryFormat")){
            arr = input.getJSONArray("entryFormat");
            if (arr.length() != output.patterns.size()){
                throw new IllegalArgumentException("TableFormat Initialization Error: your number of entryFormat must match the size of the columns");
            }
            for (int i = 0; i < arr.length(); i++){
                if (!arr.isNull(i)){
                    output = output.addEntryPattern(i, arr.getString(i));
                }
            }
        }
        return output;
    }

    /**
     * Adding a list of string which represents how each column in the table is split.
     * This is meant to be called once. You can't add more format column on the top of the existing columns
     *
     * @param format    a list of string represents how each columns is split
     *                  For example: a$a#a*a is split by $, #,*, so format should
     *                  be equals to ["$","#","*]
     * @return  an instance of TableFormat object
     * @throws IllegalArgumentException if the size of format is less than 1, or addFormat has been called once
     */
    public TableFormat addFormat(String[] format){
        if (format == null || this.patterns.size() != 0 || format.length < 1){
            throw new IllegalArgumentException("TableFormat Error: format must be greater than 1 and you can't add more format on the top of the existing list of split formats");
        }
        this.patterns = new ArrayList<>();
        for (String each : format){
            this.patterns.add(new Format(each, null));
        }
        this.patterns.add(new Format("", null));
        return this;
    }

    /**
     * Add a pattern to a particular column of the table representing how the entry
     * in that column is split
     *
     * @param index the (index)th column in the order of String[] format that was used
     *              when calling addFormat
     * @param entryPattern  how the entry is split, for instance for a column with entry
     *                      like "a, b, c, c", entryPattern should be equals to ", "
     * @return  a new instance of TableFormat with the pattern added
     */
    public TableFormat addEntryPattern(int index, String entryPattern){
        if (entryPattern == null){
            return this;
        }
        if (index < 0 || index >= this.patterns.size()){
            throw new IllegalArgumentException("TableFormat Error: cannot add an entry pattern to an non-existing column");
        }
        this.patterns.get(index).entryPattern = entryPattern;
        return this;
    }

    /**
     * parse an entry with multiple value split by a given pattern
     *
     * @param input the entries
     * @param index the column index in the order how the columns are added
     * @return  a string set of values in this entry
     *
     * @throws IllegalStateException if this method was called before addFormat has been called
     * @throws IllegalArgumentException if index is out of bound (greater or equals to the number of columns)
     */
    HashSet<String> parseEntry(String input, int index){
        if (patterns.size() == 0){
            throw new IllegalStateException("TableFormat Error: patterns has not yet been initialized");
        }
        if (index >= this.patterns.size()){
            throw new IllegalArgumentException("TableFormat Error: your index is out of bound, index expected to be in between 0 and " + (this.patterns.size()-1));
        }
        if (input == null || this.patterns.get(index).entryPattern == null){
            return null;
        }
        String[] result = input.split(Pattern.quote(this.patterns.get(index).entryPattern));
        return new HashSet<>(Arrays.asList(result));
    }

    /**
     * Split the line of text into an ArrayList of string, using the specified format
     * specified by the user
     *
     * @param input the line of string we want to split
     * @return      an ArrayList of string being split using the given format. Null if the input is null.
     * @throws      IllegalStateException if this method was called before addFormat has been called
     */
    ArrayList<String> parseLine(String input){
        if (patterns.size() == 0){
            throw new IllegalStateException("TableFormat Error: patterns has not yet been initialized");
        }
        if (input == null){
            return null;
        }
        ArrayList<String> output = new ArrayList<>();
        String res = input;
        int index = 0;
        for (TableFormat.Format eachPattern : this.patterns){
            if (index == this.patterns.size()-1){
                break;
            }
            int location = res.indexOf(eachPattern.pattern);
            if (location == -1){
                throw new IllegalArgumentException("TableFormat/Input Error: Pattern cannot be found");
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

    /**
     * Get a list of column and index mapping pairs from the first line of the text file
     *
     * Example:
     * input = "col1 col2 col3 col4"
     * returns  {"col1" : 0, "col2" : 1, "col2" : 2, "col2" : 3}
     *
     * @param input the first line of the text file (which usually consists of column name)
     *
     * @return  a map of column name and its index, or null if input == null or there the entry
     * @throws      IllegalStateException if this method was called before addFormat has been called
     */
    Map<String, Integer> parseColumns(String input){
        if (patterns.size() == 0){
            throw new IllegalStateException("TableFormat Error: patterns has not yet been initialized");
        }
        if (input == null){
            return null;
        }
        List<String> columns;
        columns = this.parseLine(input);
        Map<String, Integer> col2index = new HashMap<>();
        int index = 0;
        for (String column : columns) {
            col2index.put(column, index++);
        }
        return col2index;
    }

    /**
     * An static inner class represent individual column. The pattern indicates
     * how this column is split from the next column. The entryPattern field indicates
     * how the entry in the column is split (if it holds multiple values). If the this is
     * the last column of the table then, pattern by default is equals to ""
     */
    static class Format{
        String pattern;
        String entryPattern;

        /**
         * Constructor for the static inner class
         *
         * @param pattern   how string pattern each columns in the table the split by
         * @param entryPattern  the string pattern each entries in the column are
         *                      split by. This is set to be null by default
         */
        public Format(String pattern, String entryPattern){
            this.pattern = pattern;
            this.entryPattern = entryPattern;
        }
    }
}