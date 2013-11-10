global with sharing class ActivityRemindersWidgetController {
	
	public class TaskData {
    	public Task task {get; set;}
    	public Boolean setComplete {get; set;}
    	
    	public TaskData(Task t){
    		setComplete = false;
    		task = t;
            if (t.Subject!=null) t.Subject = t.Subject.abbreviate(100);
    	}
    }
    
    private integer max_list_size=25; //sets the page size or number of rows
    public List<TaskData> tasks {get; set;}
    public Boolean showReminders {get; set;}
    public Boolean showMoreLink {get; set;}
    public Boolean checkAllReminders {get; set;}
    
    public ActivityRemindersWidgetController() {
    	checkAllReminders = false;
        loadTasks();
    }
    
    public void loadTasks() {
        tasks = new List<TaskData>();

        for(Task t : [SELECT Id
                            ,Subject
                            ,Status
                            ,Description
                            ,WhoId
                            ,WhatId
                            ,What.Name
                            ,Who.Name
                            ,ActivityDate
                            ,isClosed
                            ,ReminderDateTime
                        FROM Task
                        WHERE isClosed = false
                        AND OwnerId =: system.Userinfo.getUserId()
                        AND IsReminderSet = true
                        ORDER BY ReminderDateTime
                        LIMIT :max_list_size ]){

             tasks.add( new TaskData(t) );
    	}
           
        showReminders = !tasks.isEmpty();
        showMoreLink = (max_list_size > tasks.size());//show more link if there are more tasks
    }
    
    @RemoteAction
    global static Integer getActiveRemindersAmount(){
    	//method to poll for count of un actioned reminders
    	Integer res = [ SELECT count() 
                        FROM Task 
                        WHERE isClosed = false 
                        AND OwnerId =: system.Userinfo.getUserId() 
                        AND IsReminderSet = true 
                        AND ReminderDateTime <= : DateTime.now()];
    	return res;	
    }
    
    public void checkUncheckAllReminders(){
    	for (TaskData t : tasks){
    		t.setComplete = checkAllReminders;
    	}
    }
    
    public void completeTasks(){
    	List<Task> completeTasks = new List<Task>();
    	for(TaskData t : tasks){
    		if(t.setComplete){
    			completeTasks.add( new Task(Id=t.task.Id, Status='Completed') );
    		}
    	}
    	
    	if(!completeTasks.isEmpty()){
    		update completeTasks;
    	}
    	
    	loadTasks();
    }
    
    public PageReference newTask(){
    	return null;
    }
    
    public void refresh(){
    	loadTasks();
    }
}