/**
 * @description       : 
 * @author            : tom.h.ansley@medtronic.com
 * @last modified on  : 12-16-2020
 * @last modified by  : tom.h.ansley@medtronic.com
 * Modifications Log 
 * Ver   Date         Author                       Modification
 * 1.0   12-11-2020   tom.h.ansley@medtronic.com   Initial Version
**/
public with sharing class FileUploadController {

    /*
     * Method which returns list of objects names and API names in the system
     */
    @AuraEnabled(cacheable=true)
    public static FileUploadJobs getCurrentUserCompletedJobs()
    {
        System.debug(LoggingLevel.DEBUG, 'Starting FileUploadController.getCurrentUserCompletedJobs()');

        List<File_Upload_Job__c> userJobs = FileUploadHelper.getCurrentUserJobs(false);

        FileUploadJobs jobs = new FileUploadJobs(userJobs);

        return jobs;
    }

    /*
     * Method which returns list of objects names and API names in the system
     */
    @AuraEnabled(cacheable=true)
    public static FileUploadJobs getCurrentUserProcessingJobs()
    {
        System.debug(LoggingLevel.DEBUG, 'Starting FileUploadController.getCurrentUserProcessingJobs()');

        List<File_Upload_Job__c> userJobs = FileUploadHelper.getCurrentUserJobs(true);

        FileUploadJobs jobs = new FileUploadJobs(userJobs);

        return jobs;
    }

    /*
     * Method which returns list of objects names and API names in the system
     */
    @AuraEnabled(cacheable=true)
    public static List<SelectOption> getFileUploadConfigs()
    {
        System.debug(LoggingLevel.DEBUG, 'Starting FileUploadController.getFileUploadConfigs()');
        List<SelectOption> configListOptions = new List<SelectOption>();

        Map<String, File_Upload_Config__c> configs = FileUploadHelper.getFileUploadConfigs();

        for (String name: configs.keySet())
            configListOptions.add(new SelectOption(name, name));         

        return configListOptions;
    }

    @AuraEnabled
    public static FileData processUploadFile(String attachmentId, String fileUploadConfigName, Boolean onlyValidate)
    {
        FileData data = new FileData();
        try 
        {

            //if we are only validating
            if (onlyValidate)
            {
                //get the processed data from the file. Note that this will only contain the first 100 rows.
                Object fileData = FileUploadHelper.getValidationData(attachmentId, fileUploadConfigName);
            
                //check that the data is what we are expecting.
                if (fileData instanceof List<List<String>>) 
                {
                    data.data = (List<List<String>>) fileData;

                    //get the TOTAL row count of the processed file which is placed at the bottom of the file.
                    data.rowCount = Integer.valueOf(data.data.get(data.data.size()-1).get(1));
                    
                    //get the header names and put into its own list.
                    data.headers = data.data.remove(0);
                    
                    //remove the last row which holds the total rows processed.
                    data.data.remove(data.data.size()-1);
                }
                
            } else {
                FileUploadHelper.processData(attachmentId, fileUploadConfigName);
            }
            
        }
        catch (Exception e)
        {
            
        }    

        return data;
    }

    /*
     * Method which attempts to abort a processing job
     */
    @AuraEnabled
    public static Boolean abortProcessingJob(String jobId)
    {
        Boolean result = false;
        System.debug(LoggingLevel.DEBUG, 'Starting FileUploadController.abortProcessingJob()');
        
        if (jobId != null)
        {
            File_Upload_Job__c job = FileUploadHelper.getFileUploadJob(jobId);

            try {

                List<AsyncApexJob> asyncJobs = [SELECT Id FROM AsyncApexJob
                                           WHERE (Id = :job.Apex_Batch_Id__c
                                            OR ParentJobId = :job.Apex_Batch_Id__c)
                                            AND CreatedById = :UserInfo.getUserId()];
                
                //try to abort upload
                for (AsyncApexJob asyncJob: asyncJobs)
                    System.AbortJob(asyncJob.Id);
        
                //update the file upload job
                job.Status__c = 'Aborted';
                job.Processing_End_Time__c = System.now();
                
                update job;
                
                //update the salesforce file with the aborted status.
                ContentVersion attach = [SELECT Id, VersionData, ContentDocumentId 
                                         FROM ContentVersion
                                         WHERE Id = :job.Result_Attachment_Id__c];
                String attachBody = String.valueOf(attach.VersionData) + '--------- PROCESSING ABORTED BY USER! ---------\n';
                attach.VersionData = Blob.valueOf(attachBody);
                
                update attach;

                result = true;
                
            } catch (Exception e)
            {
                result = false;
            }

        }

        return result;
    }


    //===========================================================================
    // Inner Classes
    //===========================================================================

    public class FileUploadConfigs
    {
        public List<FileUploadConfig> configs;

        public FileUploadConfigs(List<File_Upload_Config__c> configs)
        {
            this.configs = new List<FileUploadConfig>();
            for (File_Upload_Config__c config: configs)
                this.configs.add(new FileUploadConfig(config));
        }

        @AuraEnabled(cacheable=true)
        public List<FileUploadConfig> getConfigs()
        {
            return configs;
        }

    }

    public class FileUploadConfig
    {
        public File_Upload_Config__c config;

        public FileUploadConfig(File_Upload_Config__c config)
        {
        }

        @AuraEnabled(cacheable=true)
        public String getName()
        {
            return '';
        }

    }
    public class FileUploadJobs
    {
        public List<FileUploadJob> jobs;

        public FileUploadJobs(List<File_Upload_Job__c> jobs)
        {
            this.jobs = new List<FileUploadJob>();
            for (File_Upload_Job__c job: jobs)
                this.jobs.add(new FileUploadJob(job));
        }

        @AuraEnabled(cacheable=true)
        public List<FileUploadJob> getJobs()
        {
            return jobs;
        }

    }

    public class FileUploadJob
    {
        public File_Upload_Config__c fileUploadConfig;
        public File_Upload_Job__c job;

        public FileUploadJob(File_Upload_Job__c job)
        {
            this.job = job;
        }

        @AuraEnabled(cacheable=true)
        public String getFileName()
        {
            return job.File_Name__c;
        }
            
        @AuraEnabled(cacheable=true)
        public String getConfigName()
        {
            return job.File_Upload_Config__r.Name;
        }

        @AuraEnabled(cacheable=true)
        public String getStatus()
        {
            return job.Status__c;
        }

        @AuraEnabled(cacheable=true)
        public String getOperation()
        {
            return job.File_Upload_Config__r.DML_Operation__c;
        }

        @AuraEnabled(cacheable=true)
        public Decimal getRowsInFile()
        {
            return job.Total_Rows_Processing__c;
        }

        @AuraEnabled(cacheable=true)
        public Decimal getRowsProcessed()
        {
            return job.Total_Processed_Rows__c;
        }

        @AuraEnabled(cacheable=true)
        public Decimal getTotalSuccessRows()
        {
            return job.Total_Success_Rows__c;
        }

        @AuraEnabled(cacheable=true)
        public Decimal getTotalFailedRows()
        {
            return job.Total_Failed_Rows__c;
        }

        @AuraEnabled(cacheable=true)
        public Decimal getTotalIgnoredRows()
        {
            return job.Total_Ignored_Rows__c;
        }

        @AuraEnabled(cacheable=true)
        public String getStartTime()
        {
            return String.valueOf(job.Processing_Start_Time__c);
        }

        @AuraEnabled(cacheable=true)
        public String getFinishTime()
        {
            return String.valueOf(job.Processing_End_Time__c);
        }

        @AuraEnabled(cacheable=true)
        public String getResultAttachmentId()
        {
            return job.Result_Attachment_Id__c;
        }

        @AuraEnabled(cacheable=true)
        public String getJobId()
        {
            String jobId = null;
            if (getStatus() == FileUploadHelper.STATUS_PROCESSING)
                jobId = job.Id;
            return jobId;
        }

        @AuraEnabled(cacheable=true)
        public String getResultsURL()
        {
            String strURL = null;
            if (getResultAttachmentId() != null)
                strURL = URL.getSalesforceBaseUrl().toExternalForm() + '/sfc/servlet.shepherd/version/download/' + getResultAttachmentId();
            return strURL;
        }

    }

    public class FileData
    {
        List<List<String>> data = new List<List<String>>();
        List<String> headers    = new List<String>();
        Integer rowCount        = 0;

        @AuraEnabled(cacheable=true)
        public List<List<String>> getData()
        {
            return data;
        }

        @AuraEnabled(cacheable=true)
        public Integer getRowCount()
        {
            return rowCount;
        }

        @AuraEnabled(cacheable=true)
        public List<String> getHeaders()
        {
            return headers;
        }

    }

    /* 
    * Have to build our own SelectOption object as Lightning cannot use System.SelectOption
    */
    public class SelectOption implements Comparable {
        public SelectOption(String value, String label) {
            this.value = value;
            this.label = label;
            this.disabled = false;
            this.escapeItem = false;
        }

        @AuraEnabled
        public String label { get;set; }
        @AuraEnabled
        public String value { get;set; }
        @AuraEnabled
        public Boolean disabled { get;set; }
        @AuraEnabled
        public Boolean escapeItem { get;set; }

        public Integer compareTo(Object compareTo) {
            SelectOption option2 = (SelectOption) compareTo;
            return label.compareTo(option2.label);
        }
    }

}