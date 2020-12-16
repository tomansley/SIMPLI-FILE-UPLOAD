/**
 * @description       : 
 * @author            : tom.h.ansley@medtronic.com
 * @last modified on  : 12-16-2020
 * @last modified by  : tom.h.ansley@medtronic.com
 * Modifications Log 
 * Ver   Date         Author                       Modification
 * 1.0   12-10-2020   tom.h.ansley@medtronic.com   Initial Version
**/
public with sharing class FileUploadHelper {

    private static Map<String, File_Upload_Config__c> fileUploadConfigs = null;

    public static final String STATUS_PROCESSING = 'Processing';
    public static final String STATUS_COMPLETED  = 'Completed';
    public static final String STATUS_ERROR      = 'Error';
    public static final String STATUS_ABORTED    = 'Aborted';

    public static List<File_Upload_Job__c> getCurrentUserJobs()
    {
        return getCurrentUserJobs(null);
    }

    public static File_Upload_Job__c getFileUploadJob(String jobId)
    {
        Set<String> jobIds = new Set<String>{jobId};

        Map<Id, File_Upload_Job__c> jobs = getFileUploadJobs(jobIds);
        if (jobs.size() > 0)
            return jobs.values()[0];
        else
            return null;
    }

    public static Map<Id, File_Upload_Job__c> getFileUploadJobs(Set<String> jobIds)
    {
        Map<Id, File_Upload_Job__c> jobs = new Map<Id, File_Upload_Job__c>([SELECT Id,
                                                                                    Name,
                                                                                    Current_Batch_Number__c,
                                                                                    File_Upload_Config__r.Name,
                                                                                    File_Upload_Config__r.DML_Operation__c,
                                                                                    Status__c,
                                                                                    Batch_Size__c,
                                                                                    Total_Failed_Rows__c,
                                                                                    Total_Processed_Rows__c,
                                                                                    Total_Rows_Processing__c,
                                                                                    Total_Ignored_Rows__c,
                                                                                    Total_Success_Rows__c,
                                                                                    File_Name__c,
                                                                                    Result_Attachment_Id__c,
                                                                                    Processing_Start_Time__c,
                                                                                    Processing_End_Time__c,
                                                                                    Apex_Batch_Id__c
                                                                                FROM File_Upload_Job__c
                                                                                WHERE Id IN :jobIds]);

        return jobs;
    }

    public static List<File_Upload_Job__c> getCurrentUserJobs(Boolean isProcessing)
    {
        Set<String> status = new Set<String>();
        if (isProcessing == null)     //ALL
        {
            status.add('Processing');
            status.add('Completed');
            status.add('Error');
            status.add('Aborted');
        } else if (isProcessing)      //CURRENTLY PROCESSING
        {
            status.add('Processing');
        } else {                      //FINISHED PROCESSING
            status.add('Completed');
            status.add('Error');
            status.add('Aborted');
        }

        //get the last 7 days jobs for the running user but limit to 50 jobs.
        List<File_Upload_Job__c> jobs = [SELECT Id,
                       Name,
                       Current_Batch_Number__c,
                       File_Upload_Config__r.Name,
                       File_Upload_Config__r.DML_Operation__c,
                       Status__c,
                       Batch_Size__c,
                       Total_Failed_Rows__c,
                       Total_Processed_Rows__c,
                       Total_Rows_Processing__c,
                       Total_Ignored_Rows__c,
                       Total_Success_Rows__c,
                       File_Name__c,
                       Result_Attachment_Id__c,
                       Processing_Start_Time__c,
                       Processing_End_Time__c,
                       Apex_Batch_Id__c
                FROM File_Upload_Job__c
                WHERE CreatedById = :UserInfo.getUserId()
                    AND CreatedDate = LAST_N_DAYS:7
                    AND Status__c IN :status
                ORDER BY Processing_Start_Time__c DESC
                LIMIT 50];

        return jobs;
    }

    public static File_Upload_Config__c getFileUploadConfig(String name)
    {
        loadFileUploadConfigs();
        
        return fileUploadConfigs.get(name);
            
    }
    
    public static Map<String, File_Upload_Config__c> getFileUploadConfigs()
    {
        loadFileUploadConfigs();
        
        return fileUploadConfigs;
    }

    private static void loadFileUploadConfigs()
    {
        if (fileUploadConfigs == null)
        {
            List<File_Upload_Config__c> configs = [SELECT Name,
                                                   API_Object_Name__c,
                                                   Description__c,
                                                   Forward_Page_URL__c,
                                                   Apex_Processing_Logic_Class__c,
                                                   Display_Data_Before_Processing__c,
                                                   Validation_Display_Rows__c,
                                                   First_Line_Contains_Headers__c,
                                                   Batch_Size__c,
                                                   Ignored_Errors__c,
                                                   DML_Operation__c,
                                                   Provide_Result_File_Header__c,
                                                   Provide_Result_File_Footer__c,
                                                   (SELECT Name,
                                                           API_Field_Name__c,
                                                           File_Upload_Config__c,
                                                           Foreign_Key_API_Field_Name__c
                                                    FROM File_Upload_Config_Fields__r)
                                            FROM File_Upload_Config__c];
                                            
            fileUploadConfigs = new Map<String, File_Upload_Config__c>();
            
            for (File_Upload_Config__c config: configs)
                fileUploadConfigs.put(config.Name, config);
        }
    }
    
    /*
     * Method which takes an attachment Id and a file upload config name and both validates that the file is correct based on
     * the file upload configuration that it is to be compared against. The first X rows of the file are returned along with 
     * the headers to allow the data to be displayed and verified by the user.
     */
    public static List<List<String>> getValidationData(String attachmentId, String fileUploadConfigName)
    {
        System.debug('VALIDATING DATA');
        FileUploadTypeAbstract fileUploadJob = createFileUploadJob(attachmentId, fileUploadConfigName, true);
        
        fileUploadJob.initialize();
        
        return fileUploadJob.getValidateDataFromFile();
    }
    
    /*
     * Method which takes an attachment Id and a file upload config name and kicks off the processing job.
     */
    public static FileUploadTypeAbstract processData(String attachmentId, String fileUploadConfigName)
    {
        System.debug('PROCESSING DATA');
        
        //1. Create batch job object
        FileUploadTypeAbstract fileUploadJob = createFileUploadJob(attachmentId, fileUploadConfigName, true);
        
        //2. Initialize all variables.
        fileUploadJob.initialize();
        
        if (fileUploadJob.fileUploadConfig.Provide_Result_File_Header__c)
            fileUploadJob.setFileResultHeader();
        
        //3. create job process which will hold all statistics and results
        File_Upload_Job__c job = new File_Upload_Job__c();
        job.File_Upload_Config__c = fileUploadJob.fileUploadConfig.Id;
        job.File_Name__c                 = fileUploadJob.fileName;
        job.Total_Rows_Processing__c     = fileUploadJob.totalRows-1;
        job.Processing_Start_Time__c     = System.now();
        job.Status__c                    = 'Processing';
        if (fileUploadJob.totalRows == 0)
            job.Batch_Size__c        = 0;
        else {
            Decimal totalBatches = fileUploadJob.totalRows/fileUploadJob.fileUploadConfig.Batch_Size__c;
            job.Batch_Size__c    = totalBatches.round(System.RoundingMode.UP);
        }
        insert job;

        fileUploadJob.job = job;
        
       //4. Associate the uploaded file to the processing job
       ContentDocumentLink cdl = new ContentDocumentLink();
       cdl.LinkedEntityId = job.Id;
       cdl.ContentDocumentId=attachmentId;
       cdl.ShareType = 'V';

       insert cdl;

        //5. enqueue the job for processing
        Database.executeBatch(fileUploadJob);
        
        return fileUploadJob;
    }
    
    /*
     * Method for use by developers that are creating their own FileUploadTypeAbstract concrete class. The method allows
     * a developer to easily create a new child object based on the data in the parent object. All fields in the abstract
     * class are copied across. The method also calls the childs copyDataFromParent() method and then the initialize() method
     * before returning the object.
     */
    public static FileUploadTypeAbstract instantiateChildFileUploadJob(FileUploadTypeAbstract parentFileUploadJob)
    {
        //1. Instantiate object
        FileUploadTypeAbstract batchJob = createFileUploadJob(parentFileUploadJob.sourceAttachId, parentFileUploadJob.fileUploadConfigName, false);

        //set all abstract class variables.
        batchJob.batchNum             = parentFileUploadJob.batchNum+1;
        batchJob.totalRows            = parentFileUploadJob.totalRows;
        batchJob.totalSuccess         = parentFileUploadJob.totalSuccess;
        batchJob.totalFailure         = parentFileUploadJob.totalFailure;
        batchJob.currentRow           = parentFileUploadJob.currentRow;
        batchJob.fileUploadConfig     = parentFileUploadJob.fileUploadConfig;
        batchJob.job                  = parentFileUploadJob.job;
        batchJob.resultAttachId       = parentFileUploadJob.resultAttachId;
        batchJob.fileName             = parentFileUploadJob.fileName;
        batchJob.fileUploadConfigName = parentFileUploadJob.fileUploadConfigName;
        batchJob.isChild              = true;

        //set all implementation class variables.
        batchJob.copyDataFromParent(parentFileUploadJob);


        //initialize object.
        batchJob.initialize();
        
        return batchJob;
    }

    private static FileUploadTypeAbstract createFileUploadJob(String attachmentId, String fileUploadConfigName, Boolean getAttachment)
    {
        String debug = '\n-----------------------------------------\n';
        debug += 'createFileUploadJob method called\n';
        debug += '--- Attachment Id               - ' + attachmentId + '\n';
        debug += '--- File Upload Config Name     - ' + fileUploadConfigName + '\n';
        debug += '-----------------------------------------\n';
        System.debug(debug);

        //---------------------------------------------------
        //1. get the attachment
        //---------------------------------------------------
        ContentVersion attach = null;
        if (getAttachment)
        {
            List<ContentVersion> attachments = [SELECT Title, VersionData FROM ContentVersion WHERE ContentDocumentId = :attachmentId];
    
            if (attachments.size() != 1) throw new FileUploadHelper.FileUploadException('No attachment found for provided Id - ' + attachmentId);
            else attach = attachments[0];
        } else {
            List<ContentVersion> attachments = [SELECT Title, VersionData FROM ContentVersion WHERE ContentDocumentId = :attachmentId];
    
            if (attachments.size() != 1) throw new FileUploadHelper.FileUploadException('No attachment found for provided Id - ' + attachmentId);
            else attach = attachments[0];
        }
        
        //---------------------------------------------------
        //2. get the file upload config
        //---------------------------------------------------
        File_Upload_Config__c fileUploadConfig = FileUploadHelper.getFileUploadConfig(fileUploadConfigName);

        //---------------------------------------------------
        //3. Instantiate Upload Job
        //---------------------------------------------------       
        //get the file configs type class.  Use that to create a Type object
        Type t = null;
        if (fileUploadConfig.Apex_Processing_Logic_Class__c != null)
            t = Type.forName(fileUploadConfig.Apex_Processing_Logic_Class__c);
        else
            t = Type.forName('FileUploadTypeCSV');
        
        //instantiate a new file upload batch job object using that type
        FileUploadTypeAbstract fileUploadJob    = (FileUploadTypeAbstract) t.newInstance();
        fileUploadJob.fileUploadConfig      = fileUploadConfig;
        fileUploadJob.fileUploadConfigName  = fileUploadConfigName;
        fileUploadJob.sourceAttachId        = attachmentId;
        fileUploadJob.fileName              = attach.Title;
        if (getAttachment)
            fileUploadJob.sourceAttach          = attach;

        return fileUploadJob;
    }
    
    public class FileUploadException extends Exception
    {
        
    }

}