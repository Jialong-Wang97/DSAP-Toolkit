function a=dsap_activity_state(action,a,state,stage,message)
% Workspace-only activity timestamps. A timer may repaint elapsed time but
% must never count as a computation/worker heartbeat.
nowUTC=datetime('now','TimeZone','UTC');
switch action
 case 'new'
  a=struct('State','Preparing','Stage','Startup','StartedAt',nowUTC, ...
   'LastUpdateAt',nowUTC,'Message','Starting…','WorkerState','', ...
   'ResultsReady',false,'CheckpointCount',0);
 case 'set'
  if ~strcmp(a.State,state)||~strcmp(a.Stage,stage),a.StartedAt=nowUTC;a.WorkerState='';end
  a.State=state;a.Stage=stage;a.Message=message;a.LastUpdateAt=nowUTC;
  if strcmp(state,'Ready'),a.ResultsReady=false;end
  if strcmp(state,'Completed')||strcmp(state,'Error')||strcmp(state,'Cancelled'),a.WorkerState='';end
 case 'checkpoint'
  a.LastUpdateAt=nowUTC;a.CheckpointCount=a.CheckpointCount+1;
 otherwise,error('DSAP:ActivityAction','Unknown activity action.');
end
end
