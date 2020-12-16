/**
 * @description       : 
 * @author            : tom.h.ansley@medtronic.com
 * @last modified on  : 12-15-2020
 * @last modified by  : tom.h.ansley@medtronic.com
 * Modifications Log 
 * Ver   Date         Author                       Modification
 * 1.0   12-10-2020   tom.h.ansley@medtronic.com   Initial Version
**/
public with sharing class FileUploadTypeCSV extends FileUploadTypeAbstract {
    
    private List<String> fileLines                     {get; set;} //the file lines that still need to be processed.
    private Map<String,Integer> columnNames            {get; set;} //the column names of the file being processed.
    private Map<String, Map<String, SObject>> vLookups {get; set;} //all vlookups that are used to create the records.
    
    public override void process()
    {
            
        String debug = '\n-----------------------------------------\n';
        debug += 'PROCESSING FILE UPLOAD Q\n';
        debug += '--- File Name                   - ' + fileName + '\n';
        debug += '--- File Lines Size (w/ header) - ' + fileLines.size() + '\n';
        debug += '--- File Upload Config Name     - ' + fileUploadConfigName + '\n';
        debug += '--- File Upload Config          - ' + fileUploadConfig + '\n';
        debug += '--- Column Names                - ' + columnNames + '\n';
        debug += '--- Batch Max Size              - ' + fileUploadConfig.Batch_Size__c + '\n';
        debug += '--- Batch Num                   - ' + batchNum + '\n';
        debug += '--- Current Total Successes     - ' + totalSuccess + '\n';
        debug += '--- Current Total Failures      - ' + totalFailure + '\n';
        debug += '--- Current Total Ignored       - ' + totalIgnored + '\n';
        debug += '--- Total Lines (wo/ header)    - ' + totalRows + '\n';
        debug += '--- Current Row                 - ' + currentRow + '\n';
        debug += '--- Heap Size Limit             - ' + Limits.getLimitHeapSize() + '\n';
        debug += '--- Current Heap Size           - ' + Limits.getHeapSize() + '\n';
        debug += '-----------------------------------------\n';
        System.debug(debug);
        
        List<SObject> newRecords = new List<SObject>();
        
        //get the batch of lines to process. We get a batch because we may not be able to process them all at one time.
        List<List<String>> splitBatchLines = new List<List<String>>();
        List<String> batchLines = new List<String>();
        
        for (Integer i = 0; i < fileUploadConfig.Batch_Size__c; i++)
        {
            if (fileLines.size() == 1) break;
            batchLines.add(fileLines.remove(1));
        }
        
        //now split the batchlines 
        for (Integer i = 0; i < batchLines.size(); i++)
        {
            
            //if we have an empty row then don't do anything and reduce the total row count by one.
            if (HelperString.isNullOrEmptyString(batchLines[i]) || batchLines[i] == '\r' || batchLines[i] == '\n') 
            {
                //if this is the last line in the file then ignore.
                if (fileLines.size() == 1)
                {
                    totalRows--;
                    job.Total_Rows_Processing__c--;
                    
                //otherwise set all data to blank
                } else {
                    //for each row of data
                    List<String> rowData = new List<String>();
                    for (String columnNameKey: columnNames.keySet())
                        rowData.add('');
                    
                    splitBatchLines.add(rowData);
                }               
            } else {
                
                String[] inputvalues = batchLines[i].split(',');
                inputvalues[inputvalues.size()-1] = inputvalues[inputvalues.size()-1].replace('\r', ''); //take the last value in the line and remove the carriage return
                            
                //for each row of data
                List<String> rowData = new List<String>();
                for (String columnNameKey: columnNames.keySet())
                    rowData.add(inputvalues[columnNames.get(columnNameKey)]);
                
                splitBatchLines.add(rowData);

            }        
        }
        
        //get back some heap so we don't hit limits
        batchLines = null;

        //get all vlookup data for foreign keys
        populateVLookups(splitBatchLines);
    
        for (List<String> splitBatchLine: splitBatchLines)
        {
            
            //create a new record based on the config
            Type t = Type.forName(fileUploadConfig.API_Object_Name__c);
            if (t == null)
            {
                throw new FileUploadHelper.FileUploadException('The configured API object name cannot be found - ' + fileUploadConfig.API_Object_Name__c);
            }
            SObject objData = (SObject) t.newInstance();
            Boolean objDataError = false;
            String rowErrors = currentRow + ' - Bad data - ';
                
            for (File_Upload_Config_Field__c field: fileUploadConfig.File_Upload_Config_Fields__r)
            {
                //if we do NOT have a vlookup
                if (field.Foreign_Key_API_Field_Name__c == null) 
                {
                    //get the type of the configured field
                    Schema.DisplayType fieldType = HelperSchema.getFieldType(fileUploadConfig.API_Object_Name__c, field.API_Field_Name__c);
                    
                    //get the data as a string
                    String strData = splitBatchLine.get(columnNames.get(field.Name));

                    if (fieldType == Schema.DisplayType.Boolean) {
                        if (HelperString.isNullOrEmptyString(strData)) strData = 'false';
                        objData.put(field.API_Field_Name__c, Boolean.valueOf(strData));
                    } else if (fieldType == Schema.DisplayType.Double) {
                        if (HelperString.isNullOrEmptyString(strData)) strData = '0';
                        objData.put(field.API_Field_Name__c, Decimal.valueOf(strData));
                    } else if (fieldType == Schema.DisplayType.Integer) {
                        if (HelperString.isNullOrEmptyString(strData)) strData = '0';
                        objData.put(field.API_Field_Name__c, Integer.valueOf(strData));
                    } else if (fieldType == Schema.DisplayType.Percent) {
                        if (HelperString.isNullOrEmptyString(strData)) strData = '0';
                        objData.put(field.API_Field_Name__c, Integer.valueOf(strData));
                    } else if (fieldType == Schema.DisplayType.Currency) {
                        if (HelperString.isNullOrEmptyString(strData)) strData = '0.00';
                        objData.put(field.API_Field_Name__c, Decimal.valueOf(strData));
                    } else if (fieldType == Schema.DisplayType.Date) {
                        if (HelperString.isNullOrEmptyString(strData)) 
                        {
                            strData = '';
                            objData.put(field.API_Field_Name__c, null);
                        } else {
                            try {
                                //needs to be formatted like '10/14/2011'
                                objData.put(field.API_Field_Name__c, HelperDate.getDateFromString(strData));
                            } catch (Exception e)
                            {
                                throw new FileUploadHelper.FileUploadException('All Date fields must be in the following format - 10/14/2011 - value provided = ' + strData);
                            }
                        }
                    } else if (fieldType == Schema.DisplayType.DateTime) {
                        if (HelperString.isNullOrEmptyString(strData)) 
                        {
                            strData = '';
                            objData.put(field.API_Field_Name__c, null);
                        } else {
                            try {
                                //needs to be formatted like '10/14/2011 11:46 AM'
                                objData.put(field.API_Field_Name__c, DateTime.parse(strData));
                            } catch (Exception e)
                            {
                                throw new FileUploadHelper.FileUploadException('All DateTime fields must be in the following format - 10/14/2011 11:46 AM - value provided = ' + strData);
                            }
                        }
                    } else if (fieldType == Schema.DisplayType.Picklist) {
                        objData.put(field.API_Field_Name__c, strData);
                    } else {
                        objData.put(field.API_Field_Name__c, strData);
                    } 
                    
                //if we have a lookup
                } else {
                    
                    //get the cell data before lookup
                    String cellData = splitBatchLine.get(columnNames.get(field.Name));
                    
                    if (cellData != '')
                    {
                        
                        //get the available lookups
                        Map<String, SObject> vlookupsTmp = vLookups.get(field.Name);
                        
                        //get the correct lookup object
                        SObject obj = vLookupsTmp.get(cellData);
                        
                        //if there was no object found with provided foreign key
                        if (obj == null)
                        {
                            objDataError = true;
                            rowErrors += field.Foreign_Key_API_Field_Name__c + ' - ' + cellData + ', ';
                            
                        //if object was found then get its Id
                        } else {
                        
                            //put objects Id into record.
                            objData.put(field.API_Field_Name__c, obj.Id);                   
                        }
                        
                    } else {
                        objDataError = true;
                        rowErrors += field.Foreign_Key_API_Field_Name__c + ' - No Data' + ', ';
                    }
                }
            }
        
            //if we don't have an error then add to records to save.        
            if (!objDataError)
            {
                newRecords.add(objData);
            } else {
                rowErrors = rowErrors.removeEnd(', ');
                fileResults += rowErrors + '\n';
                totalFailure++;
            }
            
            currentRow++;

        }
        
        if (splitBatchLines.size() == 0)
            currentRow++;
        
        //get back some heap so we don't hit limits
        splitBatchLines = null;

        List<Database.Error> errors = new List<Database.Error>();
                    
        //INSERT
        if (fileUploadConfig.DML_Operation__c == 'Insert')
        {
                
            Database.SaveResult[] results = Database.insert(newRecords, false);
            for (Database.SaveResult sr : results) 
            {
                if (!sr.isSuccess()) errors.add(sr.getErrors()[0]);
                else totalSuccess++;
            }
                
        } else if (fileUploadConfig.DML_Operation__c == 'Update')
        {
            Database.SaveResult[] results = Database.update(newRecords, false);
            for (Database.SaveResult sr : results) 
            {
                if (!sr.isSuccess()) errors.add(sr.getErrors()[0]);
                else totalSuccess++;
            }

        } else if (fileUploadConfig.DML_Operation__c == 'Delete')
        {
            Database.DeleteResult[] results = Database.delete(newRecords, false);
            for (Database.DeleteResult sr : results) 
            {
                if (!sr.isSuccess()) errors.add(sr.getErrors()[0]);
                else totalSuccess++;
            }

        } else { 
            throw new FileUploadHelper.FileUploadException('DML Operation for file upload configurations that do not use an custom apex class must be one of Insert, Update or Delete.');
        }
            
        //get ignored errors setup to check for failures that should be ignored.
        List<String> ignoredErrors = new List<String>();
        if (fileUploadConfig.Ignored_Errors__c != null)
            ignoredErrors = fileUploadConfig.Ignored_Errors__c.split('\\|\\|');
            
        //Process errors                
        for(Database.Error err : errors) 
        {

            //check if failure should be ignored
            Boolean ignore = false;
            for (String ignoredError: ignoredErrors)
            {
                //if we find a failure to ignore then notify and break.
                if (err.getMessage().contains(ignoredError))
                {
                    ignore = true;
                    break;
                }
            }
                        
            if (!ignore)
            {
                totalFailure++;
                fileResults += err.getStatusCode() + ': ' + err.getMessage() + '\n';
            } else {
                totalIgnored++;
            }

        }
            
        errors = null;
        
    }
    
    public override void initialize()
    {
        //we only want to initialize on the first batch. After that the file lines get copied from parent to child.
        if (fileLines == null)
        {
            String debug = '\n--------------------------------------------------------------------\n';
            debug += 'Initialization -\n';
    
            //split the file into single lines
            filelines = HelperString.safeSplit(sourceAttach.VersionData.toString(), '\n'); //have to use safe split otherwise governor limits will break it.
    
            //get the first line and break into a map so we know what the columns are
            String[] columnFields = filelines[0].split(',');
            columnNames = new Map<String,Integer>();
            Integer index = 0;
            for (String columnField: columnFields)
                columnNames.put(columnField.replace('\r', ''), index++); //this is needed to remove the carriage return for the last column
                
            debug += '--- Column Names and Indices\n';
            for (String columnNameKey: columnNames.keySet())
                debug += 'Column Name - ' + columnNameKey + ', INDEX - ' + columnNames.get(columnNameKey) + '\n';
            debug += '---\n';
            
            //ensure all the columns we are expecting exist in the file.
            for (File_Upload_Config_Field__c field: fileUploadConfig.File_Upload_Config_Fields__r)
            {
                if (columnNames.get(field.Name) == null) throw new FileUploadHelper.FileUploadException('File upload is not valid. A column with name "' + field.Name + '" does not exist.');
            }
            
            totalRows = fileLines.size();
            
            debug += '--------------------------------------------------------------------\n';
            System.debug(debug);
        }
    }
   
    public override List<List<String>> getValidateDataFromFile()
    {

        String debug = '\n--------------------------------------------------------------------\n';
        debug += 'Validate Data -\n';

        List<List<String>> allData = new List<List<String>>();
        
        //determine number of rows to return, default to 5
        Integer rowsToReturn = 5;
        if (fileUploadConfig.Validation_Display_Rows__c != null)
            rowsToReturn = Integer.valueOf(fileUploadConfig.Validation_Display_Rows__c);

        for (Integer i = 0; i < filelines.size(); i++)
        {
            String[] inputvalues = filelines[i].split(',');
            
            List<String> rowData = new List<String>();

            //we have less columns than expected.
            if (inputvalues.size() < columnNames.size())
            {
                //let the user know we have invalida data in all columns.
                for (String columnNameKey: columnNames.keySet())
                    rowData.add('*** Invalid Data *** ');
            } else {
                
                inputvalues[inputvalues.size()-1] = inputvalues[inputvalues.size()-1].replace('\r', ''); //take the last value in the line and remove the carriage return
                
                debug += '---------- Index - ' + i + '\n';
                                
                //for each column
                for (String columnNameKey: columnNames.keySet())
                {
                    
                    String value = inputvalues[columnNames.get(columnNameKey)];
                    
                    if (value == '')
                    {
                        value = '*** Blank ***';
                    }
                    debug += 'Column - ' + columnNameKey + ', Value - ' + value + '\n';
                    rowData.add(value);
                }

            }
                        
            allData.add(rowData);

            //break if we have reached specified number of rows.
            if (i == rowsToReturn) break;
    
        }
            
        //add the total number of lines that exist in the file to the bottom.
        List<String> rowData = new List<String>();
        rowData.add('TOTAL ROWS');
        rowData.add(filelines.size() + '');
        allData.add(rowData);
                    
        debug += '--------------------------------------------------------------------\n';
        System.debug(debug);
        
        return allData;
    }
    
    public override void copyDataFromParent(FileUploadTypeAbstract fileUploadJobParent)
    {
        FileUploadTypeCSV parent = (FileUploadTypeCSV) fileUploadJobParent;
        
        this.fileLines = parent.fileLines;
        this.columnNames = parent.columnNames;
    }
    
    public override void setFileResultFooter()
    {
        fileResults += '----------------------------------------------------------------------\n';
        fileResults += ' Total row count   - ' + job.Total_Rows_Processing__c + '\n';
        fileResults += ' Success row count - ' + totalSuccess + '\n';
        fileResults += ' Failure row count - ' + totalFailure + '\n';
        fileResults += ' Ignored row count - ' + totalIgnored + '\n';
    }
    
    public override void setFileResultHeader()
    {
        if (fileResults == '')
        {
            fileResults += 'Processing errors for file with name - ' + fileName + ' processed at ' + System.now() + '\n';
            fileResults += '----------------------------------------------------------------------\n';
        }
    }
    
    private void populateVLookups(List<List<String>> splitBatchLines)
    {
        vLookups = new Map<String, Map<String, SObject>>();
        
        //go through each field and get the vlookups.
        for (File_Upload_Config_Field__c field: fileUploadConfig.File_Upload_Config_Fields__r)
        {
            //if we have a vlookup
            if (field.Foreign_Key_API_Field_Name__c != null)
            {
                
                //get the column index where the data for this field is stored.
                Integer columnIndex = columnNames.get(field.Name);
                
                List<String> columnData = new List<String>();
                for (List<String> rowData: splitBatchLines)
                    columnData.add(rowData.get(columnIndex));
                
                String objName = field.Foreign_Key_API_Field_Name__c.subStringBefore('.');
                String objField = field.Foreign_Key_API_Field_Name__c.subStringAfter('.');
                
                String soql = 'SELECT Id, ' + objField + ' FROM ' + objName + ' WHERE ' + objField + ' IN :columnData';
                
                System.debug(LoggingLevel.DEBUG, 'SOQL - ' + soql);
                System.debug(LoggingLevel.DEBUG, 'SOQL DATA - ' + columnData);
                
                List<SObject> vLookupData = Database.query(soql);
                Map<String, SObject> vLookupDataByKey = new Map<String, SObject>();
                for (SObject objData: vLookupData)
                    vLookupDataByKey.put(String.valueOf(objData.get(objField)), objData);
                    
                vLookups.put(field.Name, vLookupDataByKey);
            }
            
        }
        
    }

}