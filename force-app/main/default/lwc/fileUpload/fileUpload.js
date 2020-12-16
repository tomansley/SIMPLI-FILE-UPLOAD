import { LightningElement, wire, track, api  } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getCurrentUserCompletedJobs from '@salesforce/apex/FileUploadController.getCurrentUserCompletedJobs';
import getCurrentUserProcessingJobs from '@salesforce/apex/FileUploadController.getCurrentUserProcessingJobs';
import getFileUploadConfigs from '@salesforce/apex/FileUploadController.getFileUploadConfigs';
import processUploadFile from '@salesforce/apex/FileUploadController.processUploadFile';
import abortProcessingJob from '@salesforce/apex/FileUploadController.abortProcessingJob';

export default class FileUpload extends LightningElement {

    wiredCurrentUserCompletedJobsResult;
    wiredCurrentUserProcessingJobsResult;
    wiredFileUploadConfigsResult;

    @api hasMainTitle         = false;
    @api mainTitle            = 'Simpli File Upload';
    @api acceptedFormats      = '.csv';

    @track selectedConfig = '';        //the file upload config name selected by the user.
    @track configs;                    //holds the list of file upload configs from which a user can choose one.
    @track completedJobs;              //holds the last 7 days of jobs completed by this user.
    @track processingJobs;             //holds all currently processing jobs
    @track spinner        = false;     //identifies if the PAGE spinner should be displayed or not.
    @track isInit         = false;     //indicates whether we need to initialize for the first time.
    @track pinnedObject   = undefined; //the config that is pinned if there is a pinned file upload config.
    @track isInitializing = false;     //indicates whether we are initializing the page or not.
    @track dataHeaders;                //holds the header information for the file being processed.
    @track rowCount;                   //the number of rows in the file being processed.
    @track rowCountString;             //the string holding verbage around row count.
    @track validationData;             //data returned to allow the user to validate correctness.
    @track attachmentId;               //the files Id provided by SFDC after uploading.

    async renderedCallback() {

        console.log('Starting renderedCallback');

        if (this.isInit === false)
        {
            //https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/bind
            //look at its use with setTimeout down the page!
            setTimeout(this.handleAutoRefreshData.bind(this), 5000);

            this.isInit = true;
        }

    }

    /*
     * Wiring to get the list of jobs that a user has run over the last 7 days (max 50)
     */
    @wire (getCurrentUserCompletedJobs, { })
    wiredCurrentUserCompletedJobs(wiredCurrentUserCompletedJobsResult) {
        console.log('Starting getCurrentUserCompletedJobs'); 
        this.wiredCurrentUserCompletedJobsResult = wiredCurrentUserCompletedJobsResult;
        const { data, error } = wiredCurrentUserCompletedJobsResult;
        if (data) {
            this.completedJobs = data.jobs; 
        } else if (error) { 
            this.error = error; 
            console.log('Error Detected ' + error.message + ' - ' + error.stackTrace); 
            this.spinnerOff();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Retrieving Completed User Jobs',
                message: 'There was an error retrieving the completed users upload jobs for the last 7 days. Please see an administrator\n\n' + error.message,
                variant: 'error',
                mode: 'sticky'
            }));
        }
        console.log('Completed getCurrentUserCompletedJobs'); 
    }

    /*
     * Wiring to get the list of jobs that a user has run over the last 7 days (max 50)
     */
    @wire (getCurrentUserProcessingJobs, { })
    wiredCurrentUserProcessingJobs(wiredCurrentUserProcessingJobsResult) {
        console.log('Starting getCurrentUserProcessingJobs'); 
        this.wiredCurrentUserProcessingJobsResult = wiredCurrentUserProcessingJobsResult;
        const { data, error } = wiredCurrentUserProcessingJobsResult;
        if (data) {
            this.processingJobs = data.jobs; 
        } else if (error) { 
            this.error = error; 
            console.log('Error Detected ' + error.message + ' - ' + error.stackTrace); 
            this.spinnerOff();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Retrieving Processing User Jobs',
                message: 'There was an error retrieving the currently processing users upload jobs. Please see an administrator\n\n' + error.message,
                variant: 'error',
                mode: 'sticky'
            }));
        }
        console.log('Processing getCurrentUserProcessingJobs'); 
    }

    /*
     * Wiring to get the list of jobs that a user has run over the last 7 days (max 50)
     */
    @wire (getFileUploadConfigs, { })
    wiredFileUploadConfigs(wiredFileUploadConfigsResult) {
        console.log('Starting getFileUploadConfigs'); 
        this.wiredFileUploadConfigsResult = wiredFileUploadConfigsResult;
        const { data, error } = wiredFileUploadConfigsResult;
        if (data) {
            this.handleUploadConfigs(data); 
        } else if (error) { 
            this.error = error; 
            console.log('Error Detected ' + error.message + ' - ' + error.stackTrace); 
            this.spinnerOff();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Retrieving File Upload Configurations',
                message: 'There was an error retrieving the file upload configurations. Please see an administrator\n\n' + error.message,
                variant: 'error',
                mode: 'sticky'
            }));
        }
        console.log('Finished getFileUploadConfigs'); 
    }

    handleConfigChange(event)
    {
        this.selectedConfig = event.target.value;
    }

    handleUploadConfigs(data)
    {
        console.log('File upload configs retrieval successful'); 
        this.configs = data; 
        this.error = undefined;
        

        if (this.configs === undefined || this.configs.length === 0)
        {
            console.log('Object list is null'); 
            this.isInit = false;
        } else {
            console.log('Configs list has been populated with size - ' + this.configs.length); 

            if (this.pinnedConfig !== undefined)
            {
                //check if we have a config that matches the users pinned config. (could be stale)
                var found = this.configs.find(element => element.value === this.pinnedConfig);

                //if we do have a config then set it and get the pinned config.
                if (found !== undefined)
                {
                    console.log('Object IS in the object list');
                    this.selectedConfig = this.pinnedConfig;
                }
                this.pinnedConfig = undefined;
            } else if (this.isInitializing === false) {
                this.spinnerOff();
            }

        }

    }

    spinnerOn() {
        this.spinner = true;
        console.log('Spinner ON');
    }

    spinnerOff() {
        if (this.isInitializing === false)
        {
            this.spinner = false;
            console.log('Spinner OFF');
        }
        //var stack = new Error().stack
        //console.log( stack )
    }

    handleUploadFinished(event) {
        this.spinnerOn();

        this.attachmentId = event.detail.files[0].documentId;

        processUploadFile({attachmentId: this.attachmentId, fileUploadConfigName: this.selectedConfig, onlyValidate: true })
        .then(result => {
            console.log('File validation successful'); 

            console.log('Row count - ' + result.rowCount);
            this.rowCount = result.rowCount - 1; //remove header count
            if (this.rowCount === 1) {
                this.rowCountString = '1 record will be processed';
            } else if (this.rowCount === 0) {
                this.rowCountString = 'There are no rows to be processed';
            } else {
                this.rowCountString = this.rowCount + ' records will be processed';
            }

            console.log('Headers   - ' + result.headers);
            this.dataHeaders = result.headers;

            console.log('Data      - ' + result.data);
            this.validationData = result.data;

        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'File NOT Processed',
                message: 'File NOT Processed',
                variant: 'error',
                mode: 'sticky'
            }));
        });

        this.spinnerOff();
    }

    handleProcessClick(event) {

        processUploadFile({attachmentId: this.attachmentId, fileUploadConfigName: this.selectedConfig, onlyValidate: false })
        .then(result => {
            console.log('File processing successful'); 

            this.dispatchEvent(new ShowToastEvent({
                title: 'File Processing Started',
                message: 'File processing has started. See below for details',
                variant: 'success',
                mode: 'dismissable'
            }));
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'File NOT Processed',
                message: 'File NOT Processed',
                variant: 'error',
                mode: 'sticky'
            }));
        });
    }

    handleCancelClick(event) {
        this.selectedConfig = '';
        this.dataHeaders = undefined;
        this.rowCount = undefined;
        this.validationData = undefined;
    }

    handleAutoRefreshData() {

        var time = new Date().getTime();
        var datetime = new Date(time);

        console.log('Refreshing data - ' + datetime);

        refreshApex(this.wiredCurrentUserCompletedJobsResult);
        refreshApex(this.wiredCurrentUserProcessingJobsResult);

        //https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/bind
        //look at its use with setTimeout down the page!
        setTimeout(this.handleAutoRefreshData.bind(this), 5000);

    }

    handleJobDeleteClick(event) {

    }

    handleJobAbortClick(event) {
        var jobId = event.target.value;

        abortProcessingJob({jobId: jobId })
        .then(result => {

            if (result === true)
            {
                console.log('Processing aborted successfully'); 

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'File processing aborted successfully',
                    variant: 'success',
                    mode: 'dismissable'
                }));
            } else {
                console.log('Processing NOT aborted'); 

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Failure',
                    message: 'File processing could not be aborted. It may have completed already.',
                    variant: 'error',
                    mode: 'sticky'
                }));

            }
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Failure',
                message: 'File processing could not be aborted. It may have completed already.',
                variant: 'error',
                mode: 'sticky'
            }));
        });

    }

}