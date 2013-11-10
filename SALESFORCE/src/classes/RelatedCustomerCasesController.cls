public with sharing class RelatedCustomerCasesController {
	
	public Case theCase {get; set;}
	public String searchParam {get; set;}
	public Map<ID, Customer> customersMap = new Map<ID, Customer>();
	public map<ID, ProductImage> productMap = new map<ID, ProductImage>();
	
	public List<Customer> customers {
		get {
			List<Customer> lCustomers = customersMap.values();
			lCustomers.sort();
			return lCustomers;
		} 
		set;
	}
	
	public List<ProductImage> products {
		get {
			List<ProductImage> lProducts = productMap.values();
			return lProducts;
		} 
		set;
	}

	private Map<Id, Customer> customrsMap {get; set;}
	// List of Account fields we need to select         
    private String selectedFields = 'ID, Name, LastName, FirstName, Email, Phone, CreatedDate'
	        					+ ' ,MailingStreet, MailingCity, MailingState, MailingCountry, MailingPostalCode'
	        					+ ' ,Account.Name, Account.Id';
	String whereStatment = '';
	
	public Boolean isCustomersEmpty { get{return theCase == null || theCase.AccountId == null;} }
	
	public RelatedCustomerCasesController(ApexPages.StandardController stdController) {
		
		Id caseId = ((Case)stdController.getRecord()).Id;
		system.debug('caseId...'+caseId);
		
		cont = new Contact();
		isInserted = 'false';
			
		//check if it is new Case 
		if(caseId != null) {
	        this.theCase = [SELECT ID
	        					  ,SuppliedEmail
	        					  ,Account.Name
	        					  ,Account.Phone
	        					  ,AccountId
	        					  ,Account.ShippingCountry
	        					  ,Account.ShippingCity
	        					  ,Account.ShippingState
	        					  ,Account.ShippingStreet
	        					  ,Account.ShippingPostalCode
	        					  ,Contact.FirstName
	        					  ,Contact.LastName
	        					  ,Contact.Email
	        					  ,Contact.Phone
	        				FROM Case 
	        				WHERE Id = :caseId];
	        
	        //select lineitems from opportunities				
	        list<OpportunityLineItem> lineItems = [SELECT ID
	        											 ,PricebookEntry.ProductCode
	        											 ,PricebookEntry.Product2.Id
	        											 ,PricebookEntry.Product2.Name
	        											 ,PricebookEntry.Product2.ImageURL__c
	        											 ,Opportunity.ID
	        											 ,Opportunity.Name
	        									   FROM OpportunityLineItem
	        									   WHERE Opportunity.AccountID = :this.theCase.AccountId];
	        									   
	        //loop through them building a list of unique products
	        for (OpportunityLineItem lineItem : lineItems) {
	        	
	        	ProductImage prodImg = new ProductImage(lineItem.PricebookEntry.Product2.Id
	        										   ,lineItem.Opportunity.ID
	        										   ,lineItem.Opportunity.Name
	        										   ,lineItem.PricebookEntry.Product2.ImageURL__c
	        										   ,lineItem.PricebookEntry.Product2.Name);
	        	
	        	productMap.put(lineItem.PricebookEntry.Product2.Id, prodImg);
	        }
	        
	        if(theCase.AccountId != null || theCase.SuppliedEmail != null){					        
	        	buildRelatedCustomersList();
	        }
		}
    }
    
    //Method builds a list of customers related to currentCase
    //Two steps select
    //1. Select All Accounts with the same Email or Phone like in Account related to current Case 
    public void buildRelatedCustomersList() {
    	String emailSearchStr = '';//variable used to build list of email address sperated with OR
    	String phoneSearchStr = '';//variable used to build list of phone address sperated with OR        
        Set<String> phones = new Set<String>();
        Set<String> emails = new Set<String>();
        
	    // 1ST STEP------------------------
	    // Condition for 1st step  --> Compare Email and Phones  					
        if (theCase.ContactId != null) {
        	whereStatment = ' WHERE Id != \'' + theCase.ContactId + '\'';
        	
        	//add the cases current account
        	List<Contact> contacts = database.query('SELECT ' + selectedFields + ' FROM Contact WHERE ID = \'' + theCase.ContactId + '\' LIMIT 1');
	        if (contacts!=null && !contacts.isEmpty()) {
	        	Customer cust = new Customer(contacts[0]);
	        	cust.score = -1;//forced it to top
	        	customersMap.put(contacts[0].ID, cust);
	        }
    	
        	if(theCase.Contact.Email != null && theCase.Contact.Email != '') {
        		emailSearchStr = buildAddToSearchQuery(emailSearchStr, theCase.Contact.Email);
        	}
        	if(theCase.Contact.Phone != null && theCase.Contact.Phone != '') { 
        		phoneSearchStr = buildAddToSearchQuery(phoneSearchStr, theCase.Contact.Phone); 
        	}
        }
        
        //take the email from the case
        if (theCase.SuppliedEmail != null && theCase.SuppliedEmail != '') {
    		emailSearchStr = buildAddToSearchQuery(emailSearchStr, theCase.SuppliedEmail);
    	}
    	
        // Build query for 1st Step
        List<Contact> searchResults = searchForCustomers(emailSearchStr, phoneSearchStr, selectedFields, whereStatment);
        system.debug('searchResults...'+searchResults);
        
        // 1st step Select list of related Customers
        for(Contact contact : searchResults){
        	//build phones and emails list for 2nd step
        	if (contact.Phone != null && contact.Phone != '') { 
				phoneSearchStr = buildAddToSearchQuery(phoneSearchStr, contact.Phone); 
        	}
        	if (contact.Email != null && contact.Email != '') { 
				emailSearchStr = buildAddToSearchQuery(emailSearchStr, contact.Email);  
        	}
		}
		
		// 2ND STEP-------requery with additional emails and phone
		searchResults = searchForCustomers(emailSearchStr, phoneSearchStr, selectedFields, whereStatment);
		system.debug('searchResults...'+searchResults);

		for(Contact contact : searchResults){
			customersMap.put(contact.Id, new Customer(contact));
		}
		
        //Select related open Cases
        fillCases(customersMap.keyset());
    }
    
    //method fill customers with their cases
    public void fillCases(Set<Id> contactIds){
    	 //Select related open Cases
        for(Case c : [ SELECT CaseNumber
        					 ,Subject
        					 ,Origin
        					 ,Status
        					 ,OwnerId
        					 ,Owner.Name
        					 ,AccountId
        					 ,ContactId
        					 ,CreatedDate 
        				FROM Case 
        				WHERE ContactId IN : contactIds
        				AND IsClosed = false] ){
        					
        	if (c.ContactId!=null) {
        		customersMap.get(c.ContactId).cases.add(c);
        	}
       	}
       	        
        //select and add top 5 closed Cases to the end of cases List
        map<Id, Contact> contactsWithClosedCases = new Map<Id, Contact>(
        			[SELECT ID
        				   ,(SELECT CaseNumber
        				   		   ,Subject
        				   		   ,Origin
        				   		   ,OwnerId
        				   		   ,Owner.Name
        				   		   ,AccountId
        				   		   ,ContactId
        				   		   ,Status
        				   		   ,CreatedDate 
        					 FROM Cases 
        					 WHERE isClosed = true 
        					 ORDER BY ClosedDate LIMIT 5)  
					  FROM Contact 
					  WHERE Id IN :contactIds]);
					
        for(Customer cust : customersMap.values()){
        	Contact contact = contactsWithClosedCases.get(cust.contact.Id);
        	if (contact!=null) {
	        	List<Case> closedCases = contact.Cases;
	        	if (closedCases != null) cust.cases.addAll(closedCases);
        	}
        }
    }
    
    //Method relate current Case with selected Account. Account Id is passed like page parametr
    public PageReference relateAccount(){
    	String caseId = ApexPages.currentPage().getParameters().get('caseId');
    	String accountId = ApexPages.currentPage().getParameters().get('accountId');
    	String contactId = ApexPages.currentPage().getParameters().get('contactId');
    	
    	system.debug('caseId...'+caseId);
    	system.debug('accountId...'+accountId);
    	Case c = new Case(Id = caseId, AccountId = accountId, ContactId = contactId);
    	update c;
    	
    	PageReference ref = ApexPages.currentPage();
    	return ref;
    }
    
    // search Customers when there isnot customer assosiated with Case
    public void searchCustomers(){
    	
    	customersMap = new Map<Id, Customer>();
    	
    	String checkSymbolsAmount = searchParam.replaceAll('\\*', '');
    	checkSymbolsAmount = checkSymbolsAmount.trim();
	    	
    	if (searchParam != null && checkSymbolsAmount.length() > 2) {
    		
	    	String searchStr = searchParam + '*';
	    	
	    	String soslSearch = 'FIND \'' + searchStr + '\' IN ALL FIELDS RETURNING Contact ('+ selectedFields + ') LIMIT 20';
	    	list<List<Contact>> searchList = search.query(soslSearch);
            for(Contact contact : searchList[0]){
            	Customer cust = new Customer(contact);
            	customersMap.put(contact.Id, cust);
            }
            
            fillCases(customersMap.keySet());
            if(customersMap.isEmpty()){
            	ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.INFO, 'No similar contacts found.');
            	Apexpages.addMessage(myMsg);
            } else if(customersMap.size() == 20){
            	ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.INFO, 'More results');
            	Apexpages.addMessage(myMsg);
            }
    	} else {
    		ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.INFO, 'Please provide a broarder search term');
    		Apexpages.addMessage(myMsg);
    	}
    	
    }
    
    public class ProductImage {
    	public string ID {get; set;}
    	public string imageURL {get; set;}
    	public string name {get; set;}
    	public string oppID  {get; set;}
    	public string oppName  {get; set;}
    	
    	public ProductImage(string ID, string oppID, string oppName, string imageURL, string name) {
    		this.ID = ID;
    		this.oppID = oppID;
    		this.oppName = oppName;
    		this.imageURL = imageURL;
    		this.name = name;
    	}
    }
    
    public class Customer implements Comparable {
    	public Contact contact {get; set;}
    	public List<Case> cases {get; set;}
    	public Integer casesSize { get{ return cases.size(); } }
    	
    	public Integer score {get; set;}
    	
    	public Customer(Contact c){
    		contact = c;
    		cases = new List<Case>();
    		score = calculateAccountScore(c);
    	}
    	
    	// Implement the compareTo() method to sort based on the customer score
	    public Integer compareTo(Object compareTo) {
	        Customer compareToEmp = (Customer)compareTo;
	        if (compareToEmp.score == -1) return 1;//force to top of list if -1
	        if (score == compareToEmp.score) return 0;
	        if (score > compareToEmp.score) return 1;
	        return -1;        
	    }
    }

	private static String buildAddToSearchQuery(String searchQuery, String newParamter) {		

		if (searchQuery!=null && searchQuery.length()>0) {
			if (newParamter!=null && !searchQuery.contains(newParamter)) {
				searchQuery += ' OR ' + newParamter;
			}
		} else {
			searchQuery = newParamter;
		}
			
		return searchQuery;
	}
	
	private static List<Contact> searchForCustomers(string EmailSearchStr, string PhoneSearchStr, string selectedFields, string whereStatement) {
		/* search string should be formatted for SOSL e.g. '07730577175 OR 07735123424'*/
		
		List<List<SObject>> searchResultsEmails;
		List<List<SObject>> searchResultsPhones;
		if ( EmailSearchStr != null && EmailSearchStr != '') {
			String soslSearchEmail = 'FIND \'' + EmailSearchStr + '\' IN EMAIL FIELDS RETURNING Contact ('+ selectedFields + whereStatement + ') LIMIT 50';
        	system.debug('soslSearchEmail...'+soslSearchEmail);
        	searchResultsEmails = search.query(soslSearchEmail);
		}
        if ( PhoneSearchStr != null && PhoneSearchStr != '') {
        	String soslSearchPhone = 'FIND \'' + PhoneSearchStr + '\' IN Phone FIELDS RETURNING Contact ('+ selectedFields + whereStatement + ') LIMIT 50';
        	system.debug('soslSearchPhone...'+soslSearchPhone);
        	searchResultsPhones = search.query(soslSearchPhone);
        }

        //combine two search results into one list
        List<Contact> searchResults = new List<Contact>();
        if (searchResultsEmails!=null && !searchResultsEmails.isEmpty()) {
        	List<Contact> contactSearchResultsEmails = searchResultsEmails[0];
        	searchResults.addAll(contactSearchResultsEmails);
        }
        
        if (searchResultsPhones!=null && !searchResultsPhones.isEmpty()) {
        	List<Contact> contactSearchResultsPhones = searchResultsPhones[0];
        	searchResults.addAll(contactSearchResultsPhones);
        }
        
        return searchResults;
	}
	
	// Close Case as a duplicate
	public PageReference closeCaseAsDup(){
		
		String caseId = ApexPages.currentPage().getParameters().get('caseId');
		
		if (caseId != null) {
			Case caseToClose = new Case(Id = caseId
									   ,Status = 'Closed'
									   ,ParentId = theCase.Id);
    		update caseToClose;
		}
		
		PageReference ref = ApexPages.currentPage();
    	return ref;
	}
	
	// Method calculates Account score based on fields being populated
	public static Integer calculateAccountScore(Contact contect){
		Integer score = 0;
		
		if(contect.Email != null){
			score += 50;
		}
		if(contect.Phone != null){
			score += 20;
		}
		
		return score;
	}
	
	//Begin New Customer Part
	
	//Property to show or hide page blocks
	public Boolean showNewCust {
		get {
			if(showNewCust == null)
				showNewCust = false;
			return showNewCust;
		}
		set;
	}
	
	//Properties for creation of account
	public Contact cont {get;set;}
	public String isInserted {get;set;}
	
	//Update flag to show new customer dialog
	public void showNewCustomer() {
    	showNewCust = true;
    }
    
    //Update flag to show search or list of related customers
    public void showSearchOrList() {
    	showNewCust = false;
    }
    
    //Do the actual customer save.
    public void doSave() {
    	//If it hasn't been created yet.
    	if(isInserted == 'false') {
	    	try {
				//Insert customer
		    	insert cont;
		    	
		    	//If it isn't a new case, relate new customer to it
		    	if (theCase!=null) {
		    		Case c = new Case(Id = theCase.Id, ContactId = cont.ID);
		    		update c;
		    	}
		    	
		    	//Set inserted flag and requery account variable to new values.
		    	isInserted = 'true';
		    	cont = [SELECT Name
		    				  ,Phone
		    			FROM Contact 
		    			WHERE id = :cont.Id];
		    			
	     	} catch (Exception ex) {
	    		//Update messages with exception
	    		ApexPages.addMessages(ex);
	    	}
    	}	
	}
	//End New Customer Part
}