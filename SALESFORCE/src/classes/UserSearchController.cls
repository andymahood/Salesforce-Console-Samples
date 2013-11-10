public with sharing class UserSearchController {
	
    public list<User> users {get;set;}
    public string searchStr {get;set;}

    public UserSearchController() {
    	users = new list<User>();
    }

    public PageReference doSearch() {
    	if (searchStr.length()<=3) {
    		users = new list<User>();
    		return null;
    	}
		searchStr = searchStr+'*';
        list<list<SObject>> searchList = [FIND :searchStr 
        								  IN NAME FIELDS 
        								  RETURNING User (ID
												       	 ,Name
												       	 ,Phone
												       	 ,SmallPhotoUrl
												       	 WHERE IsActive = true 
       			 						  				 AND (UserType = 'Standard' OR UserType = 'CsnOnly'))];
       	users = searchList[0];	 
        return null;
    }
}