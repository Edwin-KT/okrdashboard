import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOKRData from '@salesforce/apex/OKRController.getOKRData';
import getActiveUsers from '@salesforce/apex/OKRController.getActiveUsers';
import recalculateProgress from '@salesforce/apex/OKRController.recalculateProgress';
import Id from '@salesforce/user/Id';

export default class OkrDashboard extends NavigationMixin(LightningElement) {
    @track objectives;
    @track isLoading = true;
    @track activeSections = [];
    
    @track selectedYear = ''; 
    @track selectedUser = Id;
    
    @track userOptions = [];


    @track isModalOpen = false;
    @track selectedObjectApiName = '';
    @track selectedKeyResultId = '';
    @track selectedObjectiveId = ''; 

    wiredOkrResult;

    @wire(getActiveUsers)
    wiredUsers({ error, data }) {
        if (data) {
            this.userOptions = data.map(user => {
                return { label: user.Name, value: user.Id };
            });
            this.userOptions.unshift({ label: 'All Users', value: '' });
        } else if (error) {
            console.error('Error fetching users', error);
        }
    }

    @wire(getOKRData, { year: '$selectedYear', ownerId: '$selectedUser' })
    wiredData(result) {
        this.wiredOkrResult = result;
        if (result.data) {
            this.objectives = result.data;
            if (this.activeSections.length === 0) {
                 this.activeSections = this.objectives.map(obj => obj.name); 
            }
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error:', result.error);
            this.showToast('Error', 'Error loading OKRs', 'error');
            this.isLoading = false;
        }
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value ? event.detail.value : '';
    }

    handleUserChange(event) {
        this.selectedUser = event.detail.value;
    }

    handleRefresh() {
        this.isLoading = true;
        let krIds = [];
        if (this.objectives) {
            this.objectives.forEach(obj => {
                if (obj.keyResults) {
                    obj.keyResults.forEach(kr => krIds.push(kr.id));
                }
            });
        }

        recalculateProgress({ keyResultIds: krIds })
            .then(() => {
                return refreshApex(this.wiredOkrResult);
            })
            .then(() => {
                this.showToast('Success', 'Data refreshed successfully', 'success');
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', 'Error refreshing data', 'error');
            })
            .finally(() => this.isLoading = false);
    }


    handleOpenCreateModal(event) {
        this.selectedObjectApiName = event.target.value; 
        this.selectedKeyResultId = event.target.dataset.krid;
        this.isModalOpen = true;
    }

    createObjective() {
        this.selectedObjectApiName = 'Objective__c';
        this.isModalOpen = true;
    }

    createKeyResult(event) {
        this.selectedObjectApiName = 'Key_Result__c';
        this.selectedObjectiveId = event.target.dataset.id;
        this.isModalOpen = true;
    }
    
    createTarget(event) {
        this.selectedObjectApiName = 'KR_Target__c';
        this.selectedKeyResultId = event.target.dataset.id; 
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedObjectApiName = '';
        this.selectedKeyResultId = '';
        this.selectedObjectiveId = '';
    }

    handleSuccess(event) {
        this.closeModal();
        this.showToast('Success', 'Record created!', 'success');
        this.handleRefresh(); 
    }

    handleError(event) {
        this.showToast('Error', 'Error creating record', 'error');
    }

    get isTask() { return this.selectedObjectApiName === 'Task'; }
    get isOpportunity() { return this.selectedObjectApiName === 'Opportunity'; }
    get isObjective() { return this.selectedObjectApiName === 'Objective__c'; }
    get isKeyResult() { return this.selectedObjectApiName === 'Key_Result__c'; }
    get isTarget() { return this.selectedObjectApiName === 'KR_Target__c'; }
    
    get showNameField() { 
        return this.selectedObjectApiName !== 'Task'; 
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}