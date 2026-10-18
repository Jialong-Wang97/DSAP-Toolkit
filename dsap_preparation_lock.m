function guard=dsap_preparation_lock(folder,key,cancelRequested)
% Per-source/cache-key interprocess lock. Cancelled requests never publish data.
if ~isfolder(folder),mkdir(folder);end
if nargin<3,cancelRequested=@() false;end
assert(~cancelRequested(),'DSAP:TerritoryCancelled','准备请求已取消。');
path=fullfile(folder,[key '.lock']);lock=java.io.File(path);started=tic;
while ~lock.mkdir()
 dsap_task_control('check');
 assert(~cancelRequested(),'DSAP:TerritoryCancelled','准备请求已取消。');
 assert(toc(started)<180,'DSAP:PreparationBusy','同一病例正在其他进程准备，等待超时；请稍后重试。');
 pause(.1);
end
guard=onCleanup(@() release(path));
dsap_task_control('check');
assert(~cancelRequested(),'DSAP:TerritoryCancelled','准备请求已取消。');
end
function release(path)
if isfolder(path),rmdir(path);end
end
