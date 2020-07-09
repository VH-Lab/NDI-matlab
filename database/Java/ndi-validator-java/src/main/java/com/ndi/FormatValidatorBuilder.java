package com.ndi;

import org.everit.json.schema.FormatValidator;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Map;
import java.util.List;
import java.util.Set;
import java.util.Arrays;
import java.util.zip.GZIPInputStream;

/**
 * This class is primarily used to create valid binary file that the Validator can load.
 */
public class FormatValidatorBuilder {
    Table table;
    String formatName;
    Rules rules;
    String filePath;
    ParserFormat parserformat;

    public FormatValidatorBuilder(){ }

    public FormatValidatorBuilder(AdvancedEnumFormatValidator validator){
        this.table = validator.table;
        this.formatName = validator.formatName;
        this.rules = validator.rules;
        this.filePath = validator.filePath;
        this.parserformat = validator.formats;
    }

    /**
     *
     * @param formatName  The name of our customized format tag
     *
     * @return            an instance of FormatValidatorBuilder with the field formatName being initialized
     */
    public FormatValidatorBuilder setFormatTag(String formatName){
        this.formatName = formatName;
        return this;
    }

    /**
     *
     * @param rules         The validation rules: it should be an instance of HashMap. It should contains
     *                      at least one keys: 1) "correct", 2) suggestions (which is optional), whose values
     *                      need to be an instance of java.util.List. The value of the key "correct" consist of
     *                      a list of accepted columns (that is if the user enter an entry that belongs to a entries
     *                      in one of the columns, we accept the user's entry), otherwise if the user has entered an
     *                      entries in the list of "suggestions" value's column, then the error message will provide
     *                      hint that allows user to enter the value in the corrected column
     *
     * @return              return an instance of FormatValidatorBuilder with rules being initialized
     */
    public FormatValidatorBuilder setRules(Rules rules){
        if (rules.correct.isEmpty()){
            throw new IllegalArgumentException("You must have at least one column, whose entry will be accepted by the validator");
        }
        this.rules = rules;
        return this;
    }

    /**
     * set the file path of the gzip/txt file
     *
     * @param filePath:     the given filepath
     *
     * @return              an instance of FormatValidatorBuilder with filePath initialized
     */
    public FormatValidatorBuilder setFilePath(String filePath){
        this.filePath = filePath;
        return this;
    }

    public FormatValidatorBuilder setParserFormat(ParserFormat parserFormat){
        this.parserformat = parserFormat;
        return this;
    }

    /**
     * Read the gzip file from the given file path, then convert it into an instance of Table
     * object, which can be saved to a specified directory later through calling the saveTo
     * method. This methods assumes that the row of the columns are split by a new line, and
     * the first row should specify the column names. Also make sure that each entry does not
     * contain any character that you use to split each entry in the row, or else the behavior
     * may be undefined
     *
     * @return the FormatValidatorBuilder with the table initialized
     */
    public FormatValidatorBuilder loadDataGzip() throws IOException{
        if (this.filePath == null || this.rules == null){
            throw new IllegalArgumentException("requires file path and rules to be non-null");
        }
        String filepath = this.filePath;
        ArrayList<String> secondaryIndices = new ArrayList<>();
        String primaryIndex = null;
        int firstIndex = 0;
        for (String correctColumn : this.rules.correct){
            if (firstIndex == 0){
                primaryIndex = correctColumn;
                firstIndex = -1;
                continue;
            }
            secondaryIndices.add(correctColumn);
        }
        secondaryIndices.addAll(this.rules.suggestions);
        try(InputStream fileStream = new FileInputStream(filepath);
            InputStream gzipStream = new GZIPInputStream(fileStream);
            Reader decoder = new InputStreamReader(gzipStream, StandardCharsets.UTF_8);
            BufferedReader reader = new BufferedReader(decoder)){
            String line = reader.readLine();
            Map<String, Integer> col2Index = this.parserformat.parseColumns(line);
            this.table = new Table(this.parserformat.parseLine(line), primaryIndex);
            while (line != null){
                table.addRow(this.parserformat.parseLine(line));
                line = reader.readLine();
            }
            for (String secondaryIndex : secondaryIndices){
                if (this.parserformat.patterns.get(col2Index.get(secondaryIndex)).entryPattern != null){
                    table.createIndexMultiValueColumn(secondaryIndex, this.parserformat.patterns.get(col2Index.get(secondaryIndex)));
                }
                else{
                    table.createIndex(secondaryIndex);
                }
            }
            return this;
        }
    }

    /**
     * Does everything that the loadDataGzip does, except it works for text file instead.
     * Note it is not recommended to use this method since it is slower.
     *
     * @return                  the FormatValidatorBuilder with the table initialized
     * @throws IOException      throw exception when reading file fails
     * @deprecated
     */
    public FormatValidatorBuilder loadData() throws IOException{
        if (this.filePath == null || this.rules == null){
            throw new IllegalArgumentException("requires file path and rules to be non-null");
        }
        String filepath = this.filePath;
        ArrayList<String> secondaryIndices = new ArrayList<>();
        String primaryIndex = null;
        int firstIndex = 0;
        for (String correctColumn : this.rules.correct){
            if (firstIndex == 0){
                primaryIndex = correctColumn;
                firstIndex = -1;
                continue;
            }
            secondaryIndices.add(correctColumn);
        }
        secondaryIndices.addAll(this.rules.suggestions);
        try(InputStream fileStream = new FileInputStream(filepath);
            Reader decoder = new InputStreamReader(fileStream, StandardCharsets.UTF_8);
            BufferedReader reader = new BufferedReader(decoder)){
            String line = reader.readLine();
            Map<String, Integer> col2Index = this.parserformat.parseColumns(line);
            this.table = new Table(this.parserformat.parseLine(line), primaryIndex);
            while (line != null){
                table.addRow(this.parserformat.parseLine(line));
                line = reader.readLine();
            }
            for (String secondaryIndex : secondaryIndices){
                if (this.parserformat.patterns.get(col2Index.get(secondaryIndex)).entryPattern != null){
                    table.createIndexMultiValueColumn(secondaryIndex, this.parserformat.patterns.get(col2Index.get(secondaryIndex)));
                }
                else{
                    table.createIndex(secondaryIndex);
                }
            }
            return this;
        }
    }

    /**
     * build an instance of AdvancedEnumFormatValidator based on the field set
     * in the FormatValidatorBuilder object
     *
     * @return  an instance of AdvancedEnumFormatValidator
     */
    public FormatValidator build(){
        return new AdvancedEnumFormatValidator(this);
    }

    /**
     * Perform a one-time linear search for a given entries from a gzip file. Return
     * error message if the input is not found, return null if the input is found, return the
     * expected input if input comes from one of the columns that are the values of the
     * "suggestions" key in the rules' HashMap
     *
     *
     * @param subject       the user's input, which will be validated
     *
     * @return              error message if nothing is found, null if the input is valid, expected
     *                      input if the input comes from another columns of the table
     *
     * @throws IOException  throw IOException if file can not be found or the file becomes corrupted
     */
    String gzipSearch(String subject) throws IOException {
        if (this.filePath == null || this.rules == null || this.parserformat == null) {
            throw new IllegalArgumentException("Require non-empty filepath and rules, and parserFormat");
        }
        if (rules.correct.isEmpty()) {
            throw new IllegalArgumentException("rules must contains the key correct");
        }
        try (InputStream fileStream = new FileInputStream(filePath);
             InputStream gzipStream = new GZIPInputStream(fileStream);
             Reader decoder = new InputStreamReader(gzipStream, StandardCharsets.UTF_8);
             BufferedReader reader = new BufferedReader(decoder)) {
            String line = reader.readLine();
            Map<String, Integer> col2index = this.parserformat.parseColumns(line);
            while (true) {
                line = reader.readLine();
                if (line == null) {
                    break;
                }
                List<String> words = this.parserformat.parseLine(line);
                ArrayList<String> correctOptions = new ArrayList<>();
                for (String rule : rules.correct) {
                    String entryInCurrentColumn = words.get(col2index.get(rule));
                    if (entryInCurrentColumn == null) {
                        continue;
                    }
                    Set<String> choices = this.parserformat.parseEntry(entryInCurrentColumn, col2index.get(rule));
                    if (choices != null && choices.contains(subject)) {
                        return null;
                    } else if (entryInCurrentColumn.equals(subject)) {
                        return null;
                    }
                    correctOptions.add(entryInCurrentColumn);
                }
                for (String suggestion : rules.suggestions) {
                    String correctColumnEntry = words.get(col2index.get(suggestion));
                    if (correctColumnEntry == null) {
                        continue;
                    }
                    Set<String> choices = this.parserformat.parseEntry(correctColumnEntry, col2index.get(suggestion));
                    if (choices != null && choices.contains(subject)) {
                        return "Entered " + subject + ". Expected: any one of " + correctOptions.toString();
                    } else if (correctColumnEntry.equals(subject)) {
                        return "Entered " + subject + ". Expected: any one of " + correctOptions.toString();
                    }
                }
            }
        }
        return "Entered: " + subject + ". Expected: an entry from the columns " + rules.correct;
    }

    public static void main(String[] args) throws IOException {
        long startTime = System.currentTimeMillis();
        FormatValidator fv = new FormatValidatorBuilder()
                .setParserFormat(new ParserFormat().addFormat(new String[]{"\t", "\t", "\t"})
                                                    .addEntryPattern(2, ", ")
                                                    .addEntryPattern(3, ", "))
                .setFilePath("src/main/resources/GenBankControlledVocabulary.tsv.gz")
                .setRules(new Rules().addExpectedColumns(Arrays.asList("Scientific_Name", "Synonyms"))
                        .addSuggestedColumn(Arrays.asList("Synonyms", "Other_Common_Name")))
                .setFormatTag("animal_subject")
                .loadDataGzip()
                .build();
        System.out.println(fv.validate("cat"));
        long endTime = System.currentTimeMillis();
        System.out.println("Execution time: " + (endTime-startTime)/1000.0 + "s");
    }
}
